# Cross-Platform Architecture & Guidelines (Windows & Linux)

This repository is shared across a **dual-boot environment** (Windows 10/11 and Linux/Fedora). The codebase is stored on a shared partition, which means:
> **Any modification made in Windows immediately affects Linux, and any modification made in Linux immediately affects Windows.**

To ensure that both operating systems build cleanly, run reliably, and retain all features and visual assets (including app icons), all developers and AI assistants **must strictly follow these rules**.

---

## 1. Golden Rules for Developers & AI Assistants

1. **Never make single-OS assumptions in shared code**:
   - In Dart (`lib/`), always branch OS-dependent behavior using `Platform.isWindows` and `Platform.isLinux`.
   - If a feature is only supported on one platform, wrap it in a platform check and provide a safe fallback or graceful degradation.
2. **Never break `pubspec.yaml` with mobile native-assets packages**:
   - Modern versions of some packages (such as `shared_preferences_android` >= 2.5) pull in Dart native asset hooks (`package:jni` / `package:objective_c`).
   - This triggers `build_hooks` during desktop builds and fails on Linux when `clang` is not installed next to `g++`.
   - Keep `dependency_overrides` for mobile dependencies (e.g., `shared_preferences_android: 2.4.28` and `shared_preferences_foundation: 2.4.0`) so desktop Linux/Windows builds are never blocked by mobile C/C++ hooks.
3. **Keep Method Channels synchronized**:
   - The platform channel name is `com.everdialer.ever_dialer_pc/system`.
   - If you add or modify a method on this channel, implement it in **both** native runners:
     - Linux: `linux/runner/my_application.cc`
     - Windows: `windows/runner/flutter_window.cpp`
   - In C++ runners, accept flexible argument types (e.g., `int`, `int64_t`, and `double` for volume) to avoid type casting exceptions.

---

## 2. App Icon & Window Manager Integration

### The Dual-OS Icon Architecture
- **Windows**:
  - The executable icon and taskbar icon are compiled into the binary via `windows/runner/Runner.rc` (`IDI_APP_ICON ICON "resources\\app_icon.ico"`).
  - The runtime window icon is set using Win32 `LoadIcon` / `WM_SETICON`.
- **Linux (Wayland & X11)**:
  - On **Wayland (KDE Plasma 6 / GNOME)**: The desktop compositor uses the Wayland `app_id` (`com.everdialer.ever_dialer_pc`) to match running windows to `.desktop` launcher files and cached icon themes.
  - If `com.everdialer.ever_dialer_pc.desktop` is missing or the icon name `ever_dialer_pc` is not found in `~/.local/share/icons/hicolor/<size>/apps/`, the taskbar will display a fallback gear icon.
  - On **X11**: The window manager matches `WM_CLASS` (`ever_dialer_pc`).
  - **Self-Healing Mechanism**: `linux/runner/my_application.cc` contains `ensure_desktop_and_icon_registered()` and `find_application_icon_path()`. On startup, it automatically copies the app icons into `~/.local/share/icons/hicolor/` and installs both `ever_dialer_pc.desktop` and `com.everdialer.ever_dialer_pc.desktop` into `~/.local/share/applications/`.
  - Both `.desktop` files are kept in `linux/` and installed by all packaging formats (AppImage, DEB, RPM, Arch, Tarball, and the in-app installer).

---

## 3. Platform Subsystems & Services

| Feature | Linux Implementation | Windows Implementation |
| :--- | :--- | :--- |
| **Window Frame** | GTK HeaderBar with client-side decorations (CSD) | Windows DWM borderless window with Win32 caption buttons |
| **Bluetooth Controller** | BlueZ via D-Bus / `bluetoothctl` and `linux/bt_sync_daemon.py` | WinRT / Win32 Bluetooth APIs and `windows/bt_sync_daemon.exe` |
| **Audio Endpoint** | PipeWire / WirePlumber / PulseAudio (`wpctl`, `pactl`) | Windows Core Audio COM APIs (`IAudioEndpointVolume` via `windows_audio_helper.h`) |
| **Volume Control** | Method channel `setPcVolume` via `wpctl set-volume` / `pactl` | Method channel `setPcVolume` via `IAudioEndpointVolume::SetMasterVolumeLevelScalar` |
| **Desktop Entry / Shortcut** | `~/.local/share/applications/*.desktop` & `/usr/share/applications/` | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\*.lnk` |

---

## 4. Release & Packaging Scripts

- **Linux Packaging**:
  - Script: `bash scripts/app_release.sh` (or command alias `app_release`)
  - Outputs: AppImage Setup (Recommended), AppImage Portable, DEB, RPM, Arch Linux package, and portable `.tar.gz`.
  - Output directory: `~/Downloads/Linux Release/`
- **Windows Packaging**:
  - Script: `scripts\app_release_win.bat` (or command alias `app_release_win`)
  - Outputs: Inno Setup executable installer and portable zip package.
  - Output directory: `%USERPROFILE%\Downloads\Windows Release\`

---

## 5. Pre-Commit Checklist for Any Change

Before committing or switching operating systems, run this verification checklist:

1. **Dart Analysis**:
   ```bash
   flutter analyze
   ```
   *Must report 0 issues.*

2. **Automated Tests**:
   ```bash
   flutter test
   ```
   *All tests must pass.*

3. **Linux Build**:
   ```bash
   flutter build linux --release
   ```
   *Must build with GCC/G++ cleanly without requiring Clang.*

4. **Windows Build (when booted in Windows)**:
   ```cmd
   flutter build windows --release
   ```
   *Must build with Visual Studio MSVC cleanly without type errors.*

5. **Icon & Desktop Verification**:
   - Ensure `linux/ever_dialer_pc.desktop` and `linux/com.everdialer.ever_dialer_pc.desktop` exist.
   - Ensure `windows/runner/resources/app_icon.ico` exists and is intact.

---

## 6. Dual-Boot OS Switching & Self-Healing Architecture

When switching between Windows and Linux on this shared partition, path references and build environments must remain stable without requiring manual cleanups:

1. **Automatic CMake Self-Healing**:
   - `windows/CMakeLists.txt` inspects `.dart_tool/package_config.json`. If it detects Linux paths (`/home/`), CMake automatically triggers `flutter pub get` during the build so clicking "Run" in Android Studio or VS Code on Windows never fails.
   - `linux/CMakeLists.txt` does the symmetric healing if it detects Windows drive paths (`file:///C:`).
2. **Universal Self-Healing Commands (`heal`)**:
   - The project contains zero-hardcoded dynamic healing commands that locate the repository automatically from anywhere:
     - **Windows**: Run `heal.bat`, `heal.cmd`, `heal.ps1`, or simply type `heal` in PowerShell / CMD.
     - **Linux**: Run `./heal.sh`, `./heal`, or simply type `heal` in Bash / Zsh.
   - When executed, the command cleans cross-OS package artifacts, regenerates `.dart_tool/package_config.json` with native paths, restores script permissions, and validates VS Code launch configs.
3. **VS Code Dual-Boot Integration**:
   - `.vscode/launch.json` uses platform-specific `windows` and `linux` properties on the primary launch target (`Ever Dialer PC`).
   - Clicking the green **Run** button (F5) automatically targets the correct desktop environment without manual dropdown configuration.
4. **Bluetooth & Audio Stability on Windows**:
   - Windows natively handles Bluetooth audio streaming (A2DP sink) through Windows Core Audio endpoints once the device is paired in Windows Bluetooth Settings.
   - Never call `AudioPlaybackConnection.OpenAsync()` in background loops or unpackaged threads in `windows/daemon/bt_sync_daemon.cpp`. Realtek/Intel Bluetooth drivers on Windows 11 24H2/25H2 suffer from a known kernel concurrency bug in `rtkbtfilter.sys` / `btha2dp.sys` that results in BugCheck 0x139 (KERNEL_SECURITY_CHECK_FAILURE) and instant system reboot.
   - `sync_service.dart` guards daemon execution so automated tests (`FLUTTER_TEST`) do not spawn unmanaged background daemons.
4. **Command Processor AutoRun Safety (Windows)**:
   - Ensure `HKCU:\Software\Microsoft\Command Processor\AutoRun` does not contain terminal banner commands like `fastfetch` or `neofetch`. Such commands break non-interactive batch processing in Visual Studio's `VsDevCmd.bat`, CMake, and Flutter's version detection.
5. **Git Line Ending Integrity**:
   - `.gitattributes` enforces LF endings for Linux shell scripts (`.sh`, `.desktop`, `.py`) and CRLF for Windows scripts (`.bat`, `.cmd`, `.iss`), preventing cross-OS syntax breakage.
