#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <signal.h>
#include <unistd.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  gboolean start_hidden;
  GtkWindow* window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static GtkStatusIcon* g_status_icon = nullptr;
static gboolean g_system_tray_enabled = TRUE;
static GDBusConnection* g_dbus_conn = nullptr;
static guint g_sni_object_id = 0;
static guint g_dbusmenu_object_id = 0;

static void show_or_present_window(GtkWindow* window) {
  if (window == nullptr) return;
  if (!gtk_widget_get_visible(GTK_WIDGET(window))) {
    gtk_widget_show(GTK_WIDGET(window));
  }
  gtk_window_deiconify(window);
  gtk_window_present(window);
}

static void quit_application(GtkWindow* window) {
  g_system_tray_enabled = FALSE;
  GApplication* app = g_application_get_default();
  if (app != nullptr) {
    g_application_quit(app);
  } else if (window != nullptr) {
    gtk_widget_destroy(GTK_WIDGET(window));
  }
}

static void show_tray_popup_menu(GtkWindow* window, guint button, guint32 activate_time) {
  if (window == nullptr) return;
  GtkWidget* menu = gtk_menu_new();

  GtkWidget* open_item = gtk_menu_item_new_with_label("Open App");
  g_signal_connect_swapped(open_item, "activate", G_CALLBACK(show_or_present_window), window);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), open_item);

  GtkWidget* sep = gtk_separator_menu_item_new();
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep);

  GtkWidget* quit_item = gtk_menu_item_new_with_label("Quit App");
  g_signal_connect_swapped(quit_item, "activate", G_CALLBACK(quit_application), window);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

  gtk_widget_show_all(menu);
  gtk_menu_popup_at_pointer(GTK_MENU(menu), nullptr);
}

// ── DBusMenu implementation for native desktop panel tray context menus ──────
static const gchar dbusmenu_introspection_xml[] =
  "<node>"
  "  <interface name='com.canonical.dbusmenu'>"
  "    <property name='Version' type='u' access='read'/>"
  "    <property name='Status' type='s' access='read'/>"
  "    <method name='GetLayout'>"
  "      <arg type='i' name='parentId' direction='in'/>"
  "      <arg type='i' name='recursionDepth' direction='in'/>"
  "      <arg type='as' name='propertyNames' direction='in'/>"
  "      <arg type='u' name='revision' direction='out'/>"
  "      <arg type='(ia{sv}av)' name='layout' direction='out'/>"
  "    </method>"
  "    <method name='GetGroupProperties'>"
  "      <arg type='ai' name='ids' direction='in'/>"
  "      <arg type='as' name='propertyNames' direction='in'/>"
  "      <arg type='a(ia{sv})' name='properties' direction='out'/>"
  "    </method>"
  "    <method name='GetProperty'>"
  "      <arg type='i' name='id' direction='in'/>"
  "      <arg type='s' name='name' direction='in'/>"
  "      <arg type='v' name='value' direction='out'/>"
  "    </method>"
  "    <method name='Event'>"
  "      <arg type='i' name='id' direction='in'/>"
  "      <arg type='s' name='eventId' direction='in'/>"
  "      <arg type='v' name='data' direction='in'/>"
  "      <arg type='u' name='timestamp' direction='in'/>"
  "    </method>"
  "    <method name='EventGroup'>"
  "      <arg type='a(isvu)' name='events' direction='in'/>"
  "      <arg type='ai' name='idErrors' direction='out'/>"
  "    </method>"
  "    <method name='AboutToShow'>"
  "      <arg type='i' name='id' direction='in'/>"
  "      <arg type='b' name='needUpdate' direction='out'/>"
  "    </method>"
  "  </interface>"
  "</node>";

static GVariant* build_menu_layout() {
  GVariantBuilder root_builder;
  g_variant_builder_init(&root_builder, G_VARIANT_TYPE("(ia{sv}av)"));
  g_variant_builder_add(&root_builder, "i", 0);

  // root properties
  g_variant_builder_open(&root_builder, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&root_builder, "{sv}", "children-display", g_variant_new_string("submenu"));
  g_variant_builder_close(&root_builder);

  // children array (av)
  g_variant_builder_open(&root_builder, G_VARIANT_TYPE("av"));

  // Item 1: Open App
  {
    GVariantBuilder item1;
    g_variant_builder_init(&item1, G_VARIANT_TYPE("(ia{sv}av)"));
    g_variant_builder_add(&item1, "i", 1);
    g_variant_builder_open(&item1, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&item1, "{sv}", "label", g_variant_new_string("Open App"));
    g_variant_builder_add(&item1, "{sv}", "enabled", g_variant_new_boolean(TRUE));
    g_variant_builder_close(&item1);
    g_variant_builder_open(&item1, G_VARIANT_TYPE("av"));
    g_variant_builder_close(&item1);
    g_variant_builder_add(&root_builder, "v", g_variant_builder_end(&item1));
  }

  // Item 2: Quit App
  {
    GVariantBuilder item2;
    g_variant_builder_init(&item2, G_VARIANT_TYPE("(ia{sv}av)"));
    g_variant_builder_add(&item2, "i", 2);
    g_variant_builder_open(&item2, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&item2, "{sv}", "label", g_variant_new_string("Quit App"));
    g_variant_builder_add(&item2, "{sv}", "enabled", g_variant_new_boolean(TRUE));
    g_variant_builder_close(&item2);
    g_variant_builder_open(&item2, G_VARIANT_TYPE("av"));
    g_variant_builder_close(&item2);
    g_variant_builder_add(&root_builder, "v", g_variant_builder_end(&item2));
  }

  g_variant_builder_close(&root_builder);
  return g_variant_builder_end(&root_builder);
}

static GVariant* build_group_properties(GVariant* ids_var) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a(ia{sv})"));

  GVariantIter iter;
  g_variant_iter_init(&iter, ids_var);
  gint32 id = 0;
  while (g_variant_iter_next(&iter, "i", &id)) {
    if (id == 0) {
      g_variant_builder_open(&builder, G_VARIANT_TYPE("(ia{sv})"));
      g_variant_builder_add(&builder, "i", 0);
      g_variant_builder_open(&builder, G_VARIANT_TYPE("a{sv}"));
      g_variant_builder_add(&builder, "{sv}", "children-display", g_variant_new_string("submenu"));
      g_variant_builder_close(&builder);
      g_variant_builder_close(&builder);
    } else if (id == 1) {
      g_variant_builder_open(&builder, G_VARIANT_TYPE("(ia{sv})"));
      g_variant_builder_add(&builder, "i", 1);
      g_variant_builder_open(&builder, G_VARIANT_TYPE("a{sv}"));
      g_variant_builder_add(&builder, "{sv}", "label", g_variant_new_string("Open App"));
      g_variant_builder_add(&builder, "{sv}", "enabled", g_variant_new_boolean(TRUE));
      g_variant_builder_close(&builder);
      g_variant_builder_close(&builder);
    } else if (id == 2) {
      g_variant_builder_open(&builder, G_VARIANT_TYPE("(ia{sv})"));
      g_variant_builder_add(&builder, "i", 2);
      g_variant_builder_open(&builder, G_VARIANT_TYPE("a{sv}"));
      g_variant_builder_add(&builder, "{sv}", "label", g_variant_new_string("Quit App"));
      g_variant_builder_add(&builder, "{sv}", "enabled", g_variant_new_boolean(TRUE));
      g_variant_builder_close(&builder);
      g_variant_builder_close(&builder);
    }
  }
  return g_variant_builder_end(&builder);
}

static void dbusmenu_method_call_cb(GDBusConnection* connection,
                                    const gchar* sender,
                                    const gchar* object_path,
                                    const gchar* interface_name,
                                    const gchar* method_name,
                                    GVariant* parameters,
                                    GDBusMethodInvocation* invocation,
                                    gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  if (g_strcmp0(method_name, "GetLayout") == 0) {
    GVariant* layout = build_menu_layout();
    g_dbus_method_invocation_return_value(invocation, g_variant_new("(u@(ia{sv}av))", (guint32)1, layout));
  } else if (g_strcmp0(method_name, "GetGroupProperties") == 0) {
    g_autoptr(GVariant) ids = g_variant_get_child_value(parameters, 0);
    GVariant* props = build_group_properties(ids);
    g_dbus_method_invocation_return_value(invocation, g_variant_new("(@a(ia{sv}))", props));
  } else if (g_strcmp0(method_name, "GetProperty") == 0) {
    gint32 id = 0;
    const gchar* name = nullptr;
    g_variant_get(parameters, "(is)", &id, &name);
    if (g_strcmp0(name, "label") == 0) {
      if (id == 1) {
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(v)", g_variant_new_string("Open App")));
        return;
      } else if (id == 2) {
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(v)", g_variant_new_string("Quit App")));
        return;
      }
    } else if (g_strcmp0(name, "children-display") == 0 && id == 0) {
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(v)", g_variant_new_string("submenu")));
      return;
    }
    g_dbus_method_invocation_return_value(invocation, g_variant_new("(v)", g_variant_new_string("")));
  } else if (g_strcmp0(method_name, "AboutToShow") == 0) {
    g_dbus_method_invocation_return_value(invocation, g_variant_new("(b)", FALSE));
  } else if (g_strcmp0(method_name, "Event") == 0) {
    gint32 id = 0;
    const gchar* event_id = nullptr;
    g_variant_get(parameters, "(isvu)", &id, &event_id, nullptr, nullptr);
    if (g_strcmp0(event_id, "clicked") == 0) {
      if (id == 1) {
        show_or_present_window(window);
      } else if (id == 2) {
        quit_application(window);
      }
    }
    g_dbus_method_invocation_return_value(invocation, nullptr);
  } else if (g_strcmp0(method_name, "EventGroup") == 0) {
    g_autoptr(GVariant) events = g_variant_get_child_value(parameters, 0);
    GVariantIter iter;
    g_variant_iter_init(&iter, events);
    gint32 id = 0;
    const gchar* event_id = nullptr;
    while (g_variant_iter_next(&iter, "(isvu)", &id, &event_id, nullptr, nullptr)) {
      if (g_strcmp0(event_id, "clicked") == 0) {
        if (id == 1) {
          show_or_present_window(window);
        } else if (id == 2) {
          quit_application(window);
        }
      }
    }
    GVariantBuilder err_builder;
    g_variant_builder_init(&err_builder, G_VARIANT_TYPE("ai"));
    g_dbus_method_invocation_return_value(invocation, g_variant_new("(@ai)", g_variant_builder_end(&err_builder)));
  } else {
    g_dbus_method_invocation_return_value(invocation, nullptr);
  }
}

static GVariant* dbusmenu_get_property_cb(GDBusConnection* connection,
                                          const gchar* sender,
                                          const gchar* object_path,
                                          const gchar* interface_name,
                                          const gchar* property_name,
                                          GError** error,
                                          gpointer user_data) {
  if (g_strcmp0(property_name, "Version") == 0) {
    return g_variant_new_uint32(3);
  } else if (g_strcmp0(property_name, "Status") == 0) {
    return g_variant_new_string("normal");
  }
  return nullptr;
}

// ── FreeDesktop / KDE StatusNotifierItem (SNI) D-Bus implementation ──────────
static const gchar sni_introspection_xml[] =
  "<node>"
  "  <interface name='org.kde.StatusNotifierItem'>"
  "    <property name='Category' type='s' access='read'/>"
  "    <property name='Id' type='s' access='read'/>"
  "    <property name='Title' type='s' access='read'/>"
  "    <property name='Status' type='s' access='read'/>"
  "    <property name='IconName' type='s' access='read'/>"
  "    <property name='IconThemePath' type='s' access='read'/>"
  "    <property name='ItemIsMenu' type='b' access='read'/>"
  "    <property name='Menu' type='o' access='read'/>"
  "    <method name='Activate'>"
  "      <arg type='i' name='x' direction='in'/>"
  "      <arg type='i' name='y' direction='in'/>"
  "    </method>"
  "    <method name='SecondaryActivate'>"
  "      <arg type='i' name='x' direction='in'/>"
  "      <arg type='i' name='y' direction='in'/>"
  "    </method>"
  "    <method name='ContextMenu'>"
  "      <arg type='i' name='x' direction='in'/>"
  "      <arg type='i' name='y' direction='in'/>"
  "    </method>"
  "    <method name='Scroll'>"
  "      <arg type='i' name='delta' direction='in'/>"
  "      <arg type='s' name='orientation' direction='in'/>"
  "    </method>"
  "    <signal name='NewIcon'/>"
  "    <signal name='NewStatus'>"
  "      <arg type='s' name='status'/>"
  "    </signal>"
  "  </interface>"
  "</node>";

static void sni_method_call_cb(GDBusConnection* connection,
                               const gchar* sender,
                               const gchar* object_path,
                               const gchar* interface_name,
                               const gchar* method_name,
                               GVariant* parameters,
                               GDBusMethodInvocation* invocation,
                               gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  if (g_strcmp0(method_name, "Activate") == 0 ||
      g_strcmp0(method_name, "SecondaryActivate") == 0) {
    show_or_present_window(window);
  } else if (g_strcmp0(method_name, "ContextMenu") == 0) {
    show_tray_popup_menu(window, 0, gtk_get_current_event_time());
  }
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

static GVariant* sni_get_property_cb(GDBusConnection* connection,
                                     const gchar* sender,
                                     const gchar* object_path,
                                     const gchar* interface_name,
                                     const gchar* property_name,
                                     GError** error,
                                     gpointer user_data) {
  if (g_strcmp0(property_name, "Category") == 0) {
    return g_variant_new_string("ApplicationStatus");
  } else if (g_strcmp0(property_name, "Id") == 0) {
    return g_variant_new_string("ever_dialer_pc");
  } else if (g_strcmp0(property_name, "Title") == 0) {
    return g_variant_new_string("Ever Dialer PC");
  } else if (g_strcmp0(property_name, "Status") == 0) {
    return g_variant_new_string("Active");
  } else if (g_strcmp0(property_name, "IconName") == 0) {
    return g_variant_new_string("ever_dialer_pc");
  } else if (g_strcmp0(property_name, "IconThemePath") == 0) {
    g_autofree gchar* home = g_strdup(g_get_home_dir());
    g_autofree gchar* icon_dir = g_build_filename(home, ".local", "share", "icons", "hicolor", nullptr);
    return g_variant_new_string(icon_dir);
  } else if (g_strcmp0(property_name, "ItemIsMenu") == 0) {
    return g_variant_new_boolean(FALSE);
  } else if (g_strcmp0(property_name, "Menu") == 0) {
    return g_variant_new_object_path("/MenuBar");
  }
  return nullptr;
}

G_GNUC_BEGIN_IGNORE_DEPRECATIONS
static void tray_icon_activate_cb(GtkStatusIcon* status_icon, gpointer user_data) {
  show_or_present_window(GTK_WINDOW(user_data));
}

static void tray_icon_popup_menu_cb(GtkStatusIcon* status_icon, guint button, guint activate_time, gpointer user_data) {
  show_tray_popup_menu(GTK_WINDOW(user_data), button, activate_time);
}

static void update_system_tray(GtkWindow* window, gboolean enabled) {
  g_system_tray_enabled = enabled;
  if (enabled) {
    // 1. FreeDesktop / KDE StatusNotifierItem (Wayland & modern desktop trays)
    if (g_dbus_conn == nullptr) {
      g_autoptr(GError) conn_err = nullptr;
      g_dbus_conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &conn_err);
    }
    if (g_dbus_conn != nullptr && g_sni_object_id == 0) {
      // Register com.canonical.dbusmenu for native tray context menus
      if (g_dbusmenu_object_id == 0) {
        g_autoptr(GError) menu_err = nullptr;
        g_autoptr(GDBusNodeInfo) menu_node_info = g_dbus_node_info_new_for_xml(dbusmenu_introspection_xml, &menu_err);
        if (menu_node_info != nullptr) {
          static const GDBusInterfaceVTable dbusmenu_vtable = {
            dbusmenu_method_call_cb,
            dbusmenu_get_property_cb,
            nullptr
          };
          g_dbusmenu_object_id = g_dbus_connection_register_object(
              g_dbus_conn,
              "/MenuBar",
              menu_node_info->interfaces[0],
              &dbusmenu_vtable,
              window,
              nullptr,
              &menu_err);
        }
      }

      g_autoptr(GError) reg_err = nullptr;
      g_autoptr(GDBusNodeInfo) node_info = g_dbus_node_info_new_for_xml(sni_introspection_xml, &reg_err);
      if (node_info != nullptr) {
        static const GDBusInterfaceVTable sni_vtable = {
          sni_method_call_cb,
          sni_get_property_cb,
          nullptr
        };
        g_sni_object_id = g_dbus_connection_register_object(
            g_dbus_conn,
            "/StatusNotifierItem",
            node_info->interfaces[0],
            &sni_vtable,
            window,
            nullptr,
            &reg_err);
        if (g_sni_object_id > 0) {
          g_dbus_connection_call(
              g_dbus_conn,
              "org.kde.StatusNotifierWatcher",
              "/StatusNotifierWatcher",
              "org.kde.StatusNotifierWatcher",
              "RegisterStatusNotifierItem",
              g_variant_new("(s)", "/StatusNotifierItem"),
              nullptr,
              G_DBUS_CALL_FLAGS_NONE,
              -1,
              nullptr,
              nullptr,
              nullptr);
        }
      }
    }

    // 2. Fallback GtkStatusIcon (for X11 / XFCE / MATE desktop environments)
    if (g_status_icon == nullptr) {
      g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
      g_autofree gchar* icon_path = nullptr;
      if (exe_path != nullptr) {
        g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
        icon_path = g_build_filename(
            exe_dir, "data", "flutter_assets", "assets", "icons", "app_icon.png", nullptr);
      }
      if (icon_path != nullptr && g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
        g_status_icon = gtk_status_icon_new_from_file(icon_path);
      } else {
        g_status_icon = gtk_status_icon_new_from_icon_name("ever_dialer_pc");
      }
      gtk_status_icon_set_tooltip_text(g_status_icon, "Ever Dialer PC");
      gtk_status_icon_set_visible(g_status_icon, TRUE);
      g_signal_connect(g_status_icon, "activate", G_CALLBACK(tray_icon_activate_cb), window);
      g_signal_connect(g_status_icon, "popup-menu", G_CALLBACK(tray_icon_popup_menu_cb), window);
    }
  } else {
    if (g_dbusmenu_object_id > 0 && g_dbus_conn != nullptr) {
      g_dbus_connection_unregister_object(g_dbus_conn, g_dbusmenu_object_id);
      g_dbusmenu_object_id = 0;
    }
    if (g_sni_object_id > 0 && g_dbus_conn != nullptr) {
      g_dbus_connection_unregister_object(g_dbus_conn, g_sni_object_id);
      g_sni_object_id = 0;
    }
    if (g_status_icon != nullptr) {
      gtk_status_icon_set_visible(g_status_icon, FALSE);
      g_clear_object(&g_status_icon);
    }
  }
}
G_GNUC_END_IGNORE_DEPRECATIONS

static guint32 g_last_button_time = 0;
static gint g_last_button_x = 0;
static gint g_last_button_y = 0;
static guint g_last_button = 1;

static gboolean on_window_button_press_event(GtkWidget* widget, GdkEventButton* event, gpointer user_data) {
  if (event != nullptr) {
    g_last_button = event->button;
    g_last_button_time = event->time;
    g_last_button_x = (gint)event->x_root;
    g_last_button_y = (gint)event->y_root;
  }
  return FALSE; // Let Flutter process the pointer event
}

static gboolean window_delete_event_cb(GtkWidget* widget, GdkEvent* event, gpointer user_data) {
  if (g_system_tray_enabled) {
    gtk_widget_hide(widget);
    return TRUE; // Intercept close and minimize/hide to system tray
  }
  return FALSE; // Normal close
}

static void system_channel_method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "setSystemTray") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gboolean enabled = TRUE;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* val = fl_value_lookup_string(args, "enabled");
      if (val != nullptr && fl_value_get_type(val) == FL_VALUE_TYPE_BOOL) {
        enabled = fl_value_get_bool(val);
      }
    }
    update_system_tray(window, enabled);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "minimizeWindow") == 0) {
    gtk_window_iconify(window);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "toggleMaximizeWindow") == 0) {
    gboolean is_max = gtk_window_is_maximized(window);
    if (is_max) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
    g_autoptr(FlValue) result = fl_value_new_bool(!is_max);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "closeWindow") == 0) {
    if (g_system_tray_enabled) {
      gtk_widget_hide(GTK_WIDGET(window));
    } else {
      gtk_widget_destroy(GTK_WIDGET(window));
    }
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "startDrag") == 0) {
    GdkSeat* seat = gdk_display_get_default_seat(gdk_display_get_default());
    GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
    gint root_x = 0;
    gint root_y = 0;
    if (pointer != nullptr) {
      gdk_device_get_position(pointer, nullptr, &root_x, &root_y);
    }
    if (root_x == 0 && root_y == 0) {
      root_x = g_last_button_x;
      root_y = g_last_button_y;
    }
    guint button = g_last_button > 0 ? g_last_button : 1;
    guint32 time = gtk_get_current_event_time();
    if (time == 0) {
      time = g_last_button_time > 0 ? g_last_button_time : GDK_CURRENT_TIME;
    }
    g_last_button_time = 0;

    GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
    if (pointer != nullptr && gdk_win != nullptr) {
      gdk_window_begin_move_drag_for_device(gdk_win, pointer, (gint)button, root_x, root_y, time);
    } else {
      gtk_window_begin_move_drag(window, (gint)button, root_x, root_y, time);
    }
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  if (!self->start_hidden) {
    show_or_present_window(GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view))));
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    show_or_present_window(self->window);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Force Client-Side Decorations (CSD) negotiation on Wayland (e.g. KWin in KDE Plasma).
  // Without setting a titlebar widget, KWin defaults to Server-Side Decorations (SSD)
  // and forcibly renders its own system titlebar and window frame.
  GtkWidget* empty_titlebar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_widget_set_size_request(empty_titlebar, 0, 0);
  gtk_window_set_titlebar(window, empty_titlebar);

  // Seamless client-side app design: remove system title bar and borders
  gtk_window_set_title(window, "Ever Dialer PC");
  gtk_window_set_decorated(window, FALSE);

  // Eliminate any default GTK window borders, outlines, or shadows
  GtkCssProvider* css_provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(css_provider,
      "window, window.csd, window.csd decoration, decoration { "
      "  border: none; "
      "  box-shadow: none; "
      "  margin: 0; "
      "  padding: 0; "
      "  outline: none; "
      "}", -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      gdk_screen_get_default(),
      GTK_STYLE_PROVIDER(css_provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(css_provider);

  gtk_window_set_default_size(window, 580, 720);

  // Set window icon from system theme or bundled asset fallback
  gtk_window_set_default_icon_name("ever_dialer_pc");
  gtk_window_set_icon_name(window, "ever_dialer_pc");

  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    g_autofree gchar* icon_path = g_build_filename(
        exe_dir, "data", "flutter_assets", "assets", "icons", "app_icon.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
      gtk_window_set_default_icon_from_file(icon_path, nullptr);
    }
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  gtk_widget_add_events(GTK_WIDGET(window), GDK_BUTTON_PRESS_MASK);
  g_signal_connect(window, "button-press-event", G_CALLBACK(on_window_button_press_event), nullptr);
  gtk_widget_add_events(GTK_WIDGET(view), GDK_BUTTON_PRESS_MASK);
  g_signal_connect(view, "button-press-event", G_CALLBACK(on_window_button_press_event), nullptr);

  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_event_cb), nullptr);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlMethodChannel) system_channel = fl_method_channel_new(
      messenger, "com.everdialer.ever_dialer_pc/system", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      system_channel, system_channel_method_call_cb, window, nullptr);

  update_system_tray(window, TRUE);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  self->start_hidden = FALSE;
  gboolean is_debug_session = FALSE;

  if (arguments != nullptr && *arguments != nullptr) {
    for (char** arg = *arguments + 1; *arg != nullptr; ++arg) {
      if (g_strcmp0(*arg, "--hidden") == 0 ||
          g_strcmp0(*arg, "--background") == 0 ||
          g_strcmp0(*arg, "--minimized") == 0) {
        self->start_hidden = TRUE;
      }
      if (g_str_has_prefix(*arg, "--vm-service-port") ||
          g_str_has_prefix(*arg, "--observatory-port") ||
          g_strcmp0(*arg, "--start-paused") == 0 ||
          g_strcmp0(*arg, "--enable-asserts") == 0) {
        is_debug_session = TRUE;
      }
    }
  }

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  if (g_application_get_is_remote(application)) {
    if (is_debug_session) {
      // If launching from VS Code / debugger, terminate the old instance so the new debug session can take over
      GDBusConnection* bus = g_application_get_dbus_connection(application);
      if (bus != nullptr) {
        g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
            bus,
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "GetConnectionUnixProcessID",
            g_variant_new("(s)", APPLICATION_ID),
            G_VARIANT_TYPE("(u)"),
            G_DBUS_CALL_FLAGS_NONE,
            1000,
            nullptr,
            nullptr);
        if (reply != nullptr) {
          guint32 pid = 0;
          g_variant_get(reply, "(u)", &pid);
          if (pid > 0 && pid != (guint32)getpid()) {
            kill((pid_t)pid, SIGTERM);
            g_usleep(250000); // 250ms
          }
        }
      }
    } else {
      // Normal application launch: bring existing window to the front and exit second process
      if (!self->start_hidden) {
        g_application_activate(application);
      }
      *exit_status = 0;
      return TRUE;
    }
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->start_hidden = FALSE;
  self->window = nullptr;
}

MyApplication* my_application_new() {
  // Set the program name to "ever_dialer_pc" to match the .desktop file name
  // and StartupWMClass so window managers and taskbars (e.g. KDE Plasma Wayland,
  // GNOME Shell) properly map running windows to their desktop entry and taskbar icon.
  g_set_prgname("ever_dialer_pc");

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS, nullptr));
}
