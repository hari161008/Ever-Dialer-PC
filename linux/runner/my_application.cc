#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static GtkStatusIcon* g_status_icon = nullptr;
static gboolean g_system_tray_enabled = TRUE;

G_GNUC_BEGIN_IGNORE_DEPRECATIONS
static void tray_icon_activate_cb(GtkStatusIcon* status_icon, gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  if (gtk_widget_get_visible(GTK_WIDGET(window))) {
    gtk_window_present(window);
  } else {
    gtk_widget_show(GTK_WIDGET(window));
    gtk_window_present(window);
  }
}

static void tray_icon_popup_menu_cb(GtkStatusIcon* status_icon, guint button, guint activate_time, gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  GtkWidget* menu = gtk_menu_new();

  GtkWidget* open_item = gtk_menu_item_new_with_label("Open Ever Dialer");
  g_signal_connect_swapped(open_item, "activate", G_CALLBACK(tray_icon_activate_cb), window);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), open_item);

  GtkWidget* sep = gtk_separator_menu_item_new();
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep);

  GtkWidget* quit_item = gtk_menu_item_new_with_label("Quit");
  g_signal_connect_swapped(quit_item, "activate", G_CALLBACK(gtk_widget_destroy), window);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

  gtk_widget_show_all(menu);
  gtk_menu_popup(GTK_MENU(menu), nullptr, nullptr, gtk_status_icon_position_menu, status_icon, button, activate_time);
}

static void update_system_tray(GtkWindow* window, gboolean enabled) {
  g_system_tray_enabled = enabled;
  if (enabled) {
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
    if (g_status_icon != nullptr) {
      gtk_status_icon_set_visible(g_status_icon, FALSE);
      g_clear_object(&g_status_icon);
    }
  }
}
G_GNUC_END_IGNORE_DEPRECATIONS

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
  } else {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Ever Dialer PC");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Ever Dialer PC");
  }

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

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

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

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
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

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to "ever_dialer_pc" to match the .desktop file name
  // and StartupWMClass so window managers and taskbars (e.g. KDE Plasma Wayland,
  // GNOME Shell) properly map running windows to their desktop entry and taskbar icon.
  g_set_prgname("ever_dialer_pc");

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
