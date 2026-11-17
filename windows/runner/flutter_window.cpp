#include "flutter_window.h"

#include <shellapi.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "windows_audio_helper.h"

namespace {

static bool g_system_tray_enabled = true;
static bool g_exit_on_close = false;

constexpr UINT WM_APP_TRAY = WM_APP + 1;
constexpr WORD IDM_TRAY_OPEN = 1001;
constexpr WORD IDM_TRAY_QUIT = 1002;
constexpr UINT TRAY_UID = 100;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupSystemMethodChannel();

  if (g_system_tray_enabled) {
    InitTrayIcon();
  }

  if (!IsStartHidden()) {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  DestroyTrayIcon();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetupSystemMethodChannel() {
  system_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.everdialer.ever_dialer_pc/system",
          &flutter::StandardMethodCodec::GetInstance());

  system_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HandleSystemMethodCall(call, std::move(result));
      });
}

void FlutterWindow::HandleSystemMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "minimizeWindow") {
    ShowWindow(GetHandle(), SW_MINIMIZE);
    result->Success();
  } else if (method == "toggleMaximizeWindow") {
    HWND hwnd = GetHandle();
    WINDOWPLACEMENT wp = {sizeof(WINDOWPLACEMENT)};
    GetWindowPlacement(hwnd, &wp);
    bool is_max = (wp.showCmd == SW_SHOWMAXIMIZED);
    if (is_max) {
      ShowWindow(hwnd, SW_RESTORE);
    } else {
      ShowWindow(hwnd, SW_MAXIMIZE);
    }
    result->Success(flutter::EncodableValue(!is_max));
  } else if (method == "closeWindow") {
    if (g_exit_on_close) {
      DestroyTrayIcon();
      PostQuitMessage(0);
    } else if (g_system_tray_enabled) {
      ShowWindow(GetHandle(), SW_HIDE);
    } else {
      DestroyTrayIcon();
      PostQuitMessage(0);
    }
    result->Success();
  } else if (method == "startDrag") {
    HWND hwnd = GetHandle();
    ReleaseCapture();
    SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    result->Success();
  } else if (method == "startResize") {
    HWND hwnd = GetHandle();
    std::string edge = "";
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("edge"));
      if (it != args->end() && std::holds_alternative<std::string>(it->second)) {
        edge = std::get<std::string>(it->second);
      }
    }
    WPARAM hit = HTCLIENT;
    if (edge == "left") hit = HTLEFT;
    else if (edge == "right") hit = HTRIGHT;
    else if (edge == "top") hit = HTTOP;
    else if (edge == "bottom") hit = HTBOTTOM;
    else if (edge == "topLeft" || edge == "top_left") hit = HTTOPLEFT;
    else if (edge == "topRight" || edge == "top_right") hit = HTTOPRIGHT;
    else if (edge == "bottomLeft" || edge == "bottom_left") hit = HTBOTTOMLEFT;
    else if (edge == "bottomRight" || edge == "bottom_right") hit = HTBOTTOMRIGHT;

    if (hit != HTCLIENT) {
      ReleaseCapture();
      SendMessage(hwnd, WM_NCLBUTTONDOWN, hit, 0);
    }
    result->Success();
  } else if (method == "setExitOnClose") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("enabled"));
      if (it != args->end() && std::holds_alternative<bool>(it->second)) {
        g_exit_on_close = std::get<bool>(it->second);
      }
    }
    result->Success();
  } else if (method == "setSystemTray") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("enabled"));
      if (it != args->end() && std::holds_alternative<bool>(it->second)) {
        g_system_tray_enabled = std::get<bool>(it->second);
        UpdateTrayIcon(g_system_tray_enabled);
      }
    }
    result->Success();
  } else if (method == "getPcVolume") {
    int volume = 50;
    bool muted = false;
    ever_dialer::GetMasterVolumeAndMute(&volume, &muted);
    flutter::EncodableMap map;
    map[flutter::EncodableValue("volume")] = flutter::EncodableValue(volume);
    map[flutter::EncodableValue("muted")] = flutter::EncodableValue(muted);
    result->Success(flutter::EncodableValue(map));
  } else if (method == "setPcVolume") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("volume"));
      if (it != args->end()) {
        int vol = 50;
        if (std::holds_alternative<int>(it->second)) {
          vol = std::get<int>(it->second);
          ever_dialer::SetMasterVolume(vol);
        } else if (std::holds_alternative<int64_t>(it->second)) {
          vol = static_cast<int>(std::get<int64_t>(it->second));
          ever_dialer::SetMasterVolume(vol);
        } else if (std::holds_alternative<double>(it->second)) {
          vol = static_cast<int>(std::get<double>(it->second));
          ever_dialer::SetMasterVolume(vol);
        }
      }
    }
    result->Success();
  } else if (method == "setPcMute") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("muted"));
      if (it != args->end() && std::holds_alternative<bool>(it->second)) {
        bool m = std::get<bool>(it->second);
        ever_dialer::SetMasterMute(m);
      }
    }
    result->Success();
  } else if (method == "getAudioSinks") {
    auto sinks = ever_dialer::GetAudioSinks();
    flutter::EncodableList list;
    for (const auto& s : sinks) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("name")] = flutter::EncodableValue(s.id);
      map[flutter::EncodableValue("description")] = flutter::EncodableValue(s.name);
      map[flutter::EncodableValue("isDefault")] = flutter::EncodableValue(s.is_default);
      list.push_back(flutter::EncodableValue(map));
    }
    result->Success(flutter::EncodableValue(list));
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::InitTrayIcon() {
  if (tray_icon_installed_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(NOTIFYICONDATAW);
  nid.hWnd = GetHandle();
  nid.uID = TRAY_UID;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = WM_APP_TRAY;
  nid.hIcon = (HICON)LoadImage(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON),
                               IMAGE_ICON, GetSystemMetrics(SM_CXSMICON),
                               GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
  wcscpy_s(nid.szTip, L"Ever Dialer PC");
  Shell_NotifyIconW(NIM_ADD, &nid);
  tray_icon_installed_ = true;
}

void FlutterWindow::DestroyTrayIcon() {
  if (!tray_icon_installed_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(NOTIFYICONDATAW);
  nid.hWnd = GetHandle();
  nid.uID = TRAY_UID;
  Shell_NotifyIconW(NIM_DELETE, &nid);
  tray_icon_installed_ = false;
}

void FlutterWindow::UpdateTrayIcon(bool enabled) {
  if (enabled) {
    InitTrayIcon();
  } else {
    DestroyTrayIcon();
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_APP_TRAY: {
      if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
        ShowWindow(hwnd, SW_SHOW);
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
      } else if (lparam == WM_RBUTTONUP) {
        POINT pt;
        GetCursorPos(&pt);
        HMENU hMenu = CreatePopupMenu();
        AppendMenuW(hMenu, MF_STRING, IDM_TRAY_OPEN, L"Open Ever Dialer PC");
        AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(hMenu, MF_STRING, IDM_TRAY_QUIT, L"Quit App");
        SetForegroundWindow(hwnd);
        TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, nullptr);
        DestroyMenu(hMenu);
      }
      return 0;
    }
    case WM_COMMAND: {
      WORD cmdId = LOWORD(wparam);
      if (cmdId == IDM_TRAY_OPEN) {
        ShowWindow(hwnd, SW_SHOW);
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
        return 0;
      } else if (cmdId == IDM_TRAY_QUIT) {
        DestroyTrayIcon();
        PostQuitMessage(0);
        return 0;
      }
      break;
    }
    case WM_SIZE: {
      if (system_channel_) {
        bool is_max = (wparam == SIZE_MAXIMIZED);
        system_channel_->InvokeMethod(
            "onMaximizedChanged",
            std::make_unique<flutter::EncodableValue>(is_max));
      }
      break;
    }
    case WM_CLOSE: {
      if (g_exit_on_close) {
        DestroyTrayIcon();
        PostQuitMessage(0);
      } else if (g_system_tray_enabled) {
        ShowWindow(hwnd, SW_HIDE);
      } else {
        DestroyTrayIcon();
        PostQuitMessage(0);
      }
      return 0;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
