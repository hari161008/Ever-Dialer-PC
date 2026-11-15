#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "win32_window.h"

// A window that hosts a Flutter view and bridges system methods.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void SetupSystemMethodChannel();
  void HandleSystemMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void InitTrayIcon();
  void DestroyTrayIcon();
  void UpdateTrayIcon(bool enabled);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // MethodChannel for communicating with Ever Dialer PC Flutter code.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> system_channel_;

  bool tray_icon_installed_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
