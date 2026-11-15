# Ever Dialer PC — Windows 10 & 11 Implementation Guide for AI Agents

> **Note for AI Coding Assistants (Antigravity, Gemini, Claude, Copilot, etc.):**
> Read this document completely before modifying or creating any code in this repository. It specifies the architecture, platform boundaries, and technical blueprint for making **Ever Dialer PC** fully operational on Windows 10 & 11.

---

## 🎯 Project Overview & Objective

**Ever Dialer PC** is a Flutter desktop application built with **Material You (Material 3)**.
* **Core Purpose:** Acts as a desktop companion for your Android phone, enabling Bluetooth A2DP Sink so your PC speakers play phone audio (calls, media, music, YouTube) wirelessly, with real-time audio volume control, unmuting, and Bluetooth status monitoring.
* **Primary Objective for AI:** Implement native Windows 10 (Version 2004+) & Windows 11 support with full feature parity, while ensuring that **ALL Linux functionality remains 100% intact and untouched**.

---

## ⚠️ The Golden Rule: NEVER BREAK LINUX CODE

The Linux version is in production and fully functional.
* **Do NOT delete, replace, or alter** the Linux code logic in:
  - `lib/services/bluetooth_service.dart`
  - `lib/widgets/audio_status_card.dart`
  - `lib/widgets/bluetooth_container.dart`
  - `lib/screens/installer_screen.dart`
  - `lib/screens/uninstall_screen.dart`
  - `lib/screens/about_screen.dart`
  - `linux/`
  - `scripts/app_release.sh`

### How to branch platforms:
Always guard platform-specific code with Dart's `Platform` checks:
```dart
import 'dart:io' show Platform;

if (Platform.isLinux) {
  // Existing Linux implementation (bluetoothctl, rfkill, wpctl, pactl)
} else if (Platform.isWindows) {
  // Windows 10 & 11 implementation
}
```
Or create dedicated platform services:
* `lib/services/linux_bluetooth_service.dart` (existing Linux implementation)
* `lib/services/windows_bluetooth_service.dart` (new Windows implementation)
* `lib/services/bluetooth_service.dart` (interface / factory delegating to the appropriate service)

---

## 🔍 Linux vs. Windows Mapping

| Feature | Linux Implementation | Windows 10 / 11 Equivalent |
| :--- | :--- | :--- |
| **Bluetooth Power** | `rfkill unblock bluetooth` / `bluetoothctl power on` | WinRT `Windows.Devices.Radios.Radio` API or PowerShell Radio script |
| **Discoverability & Alias** | `bluetoothctl discoverable on`, `system-alias` | Windows Settings / WinRT BluetoothAdapter |
| **A2DP Audio Sink** | PipeWire / PulseAudio A2DP sink profile | WinRT Bluetooth A2DP Sink (supported natively in Win 10 2004+ and Win 11) |
| **Speaker Volume / Mute** | `wpctl get-volume @DEFAULT_AUDIO_SINK@`, `wpctl set-mute` | Windows CoreAudio API (`IAudioEndpointVolume` via COM) or PowerShell CoreAudio |
| **Audio Output Device List** | `pactl list sinks` | Windows Multimedia Device APIs (`IMMDeviceEnumerator`) |
| **Opening Links** | `Process.run('xdg-open', [url])` | `Process.run('cmd', ['/c', 'start', '', url])` or `url_launcher` |
| **Installer / App Setup** | Linux `.desktop` in `/usr/share/applications/` | Standalone portable bundle / ZIP / optional Inno Setup |
| **Release Command** | `app_release` -> `~/Downloads/Linux Release/` | `app_release_win` -> `%USERPROFILE%\Downloads\Windows Release\` |

---

## 🛠️ Windows Technical Implementation Blueprint

### 1. Bluetooth A2DP Sink on Windows 10 & 11

In Windows 10 Version 2004 and Windows 11, Microsoft reintroduced native Bluetooth A2DP Sink support.
When a phone pairs with Windows, Windows creates a Bluetooth audio endpoint, but it requires activating the A2DP Sink role.

#### Recommended Approaches for the AI:

**Option A (C++ Native Runner / MethodChannel — Recommended for clean performance):**
Add a lightweight MethodChannel in `windows/runner/flutter_window.cpp` or a C++ plugin that talks to WinRT:
```cpp
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Media.Audio.h>
```
Register method calls:
* `toggleBluetooth(bool enable)`
* `getConnectedDevices()`
* `activateA2DPSink()`

**Option B (PowerShell / Process.run — Fastest implementation matching Linux pattern):**
Execute PowerShell commands asynchronously from Dart without external dependencies:
* Check Bluetooth Radio:
  ```powershell
  [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
  $radios = [Windows.Devices.Radios.Radio]::GetRadiosAsync().GetAwaiter().GetResult()
  $bt = $radios | Where-Object { $_.Kind -eq 'Bluetooth' }
  # Turn on:
  $bt.SetStateAsync('On').GetAwaiter().GetResult()
  ```

---

### 2. Audio Volume & Unmute on Windows

Windows manages volume through the CoreAudio COM interface `IAudioEndpointVolume`.

#### Dart FFI Implementation (`win32` package):
Add `win32` dependency in `pubspec.yaml` (it is safe to have; on Linux it is ignored):
```yaml
dependencies:
  win32: ^5.5.0
```
Then use `MMDeviceEnumerator` and `IAudioEndpointVolume`:
```dart
import 'package:win32/win32.dart';

// Get master volume (0.0 to 1.0)
// Set master volume
// Check if muted / unmute
```

#### Alternative: PowerShell Audio Helper:
```powershell
# Get volume and mute status via .NET or CoreAudio script
```

---

### 3. Screen Adaptations for Windows

#### `installer_screen.dart`
The installer screen currently manages Linux desktop files (`/usr/share/applications/`, `pkexec`, `chmod`).
On Windows:
* Check `Platform.isWindows`.
* Show a Windows-tailored screen or prompt:
  *"Ever Dialer PC is running in Portable Mode. You can create a desktop shortcut or pin to Start."*
* To create a Windows desktop shortcut via Dart:
  ```powershell
  $WshShell = New-Object -ComObject WScript.Shell;
  $Shortcut = $WshShell.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Ever Dialer PC.lnk");
  $Shortcut.TargetPath = "$exePath";
  $Shortcut.Save();
  ```

#### `about_screen.dart`
Replace direct `xdg-open` call with a platform-safe helper:
```dart
void openUrl(String url) async {
  if (Platform.isLinux) {
    await Process.run('xdg-open', [url]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
  }
}
```

---

## 📦 Windows Release & Packaging Workflow

### Release Command: `app_release_win`
On Windows, the user or AI should run:
```cmd
app_release_win
```
or in PowerShell:
```powershell
.\scripts\app_release_win.ps1
```

### What `app_release_win` does automatically:
1. Detects `pubspec.yaml` version.
2. Checks that Flutter is installed.
3. Automatically runs `flutter create --platforms=windows .` if `windows/` is not yet generated.
4. Executes `flutter build windows --release`.
5. Gathers the executable and runtime libraries from `build\windows\x64\runner\Release\`.
6. Packages them into:
   ```
   %USERPROFILE%\Downloads\Windows Release\Ever-Dialer-PC-v<version>-windows-x64\
   ```
7. Generates a compressed `.zip` archive ready for distribution:
   ```
   %USERPROFILE%\Downloads\Windows Release\Ever-Dialer-PC-v<version>-windows-x64.zip
   ```

---

## 📋 Verification Checklist for AI Agent

When implementing on Windows, verify each item:
- [ ] `flutter run -d windows` starts the app without compile or runtime errors.
- [ ] Toggling Bluetooth switch properly engages Bluetooth radio without crashing.
- [ ] PC speakers volume slider reflects system volume and unmuting functions correctly.
- [ ] Phone can connect via Bluetooth and audio streams through PC speakers.
- [ ] Running `app_release_win` outputs the packaged release into `%USERPROFILE%\Downloads\Windows Release\`.
- [ ] Running `app_release` on Linux still functions 100% without errors.
