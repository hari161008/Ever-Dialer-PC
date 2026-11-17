# Ever Dialer PC 📱🔊

A native cross-platform desktop application built with **Flutter & Dart** for **Windows 10/11** and **Linux (Fedora, Ubuntu, Debian, Arch)**, featuring **Android Material You (Material 3)** dynamic theming and a **Bluetooth Connection** container that turns your PC into a wireless media speaker for your phone.

---

> [!IMPORTANT]
> **Dual-Boot / Shared Disk Note**:
> This repository is actively developed in a dual-boot environment shared between Windows and Linux. Any modifications must maintain compatibility with both platforms. See [CROSS_PLATFORM_GUIDELINES.md](CROSS_PLATFORM_GUIDELINES.md) for architecture rules, platform channel requirements, and app icon handling.

---

## ✨ Features

- **Android Material You (Material 3) Design**:
  - Powered by Flutter's native Material 3 design system with `dynamic_color`.
  - Automatically queries and applies your KDE/Windows system accent color (e.g. Amber/Gold `#FFDD31`) with full dynamic tonal mapping (Primary, Surface, Surface Container, On-Primary, etc.).
  - Smooth animated **M3 Switch** with pill track and sliding thumb with checkmark glyph.
  - Large rounded squircle cards (28dp radii), full-pill chips, and interactive 3-step phone pairing guide.
  - System, Dark, and Light mode dynamic switching with instant hot reload.
- **Bluetooth Connection Container**:
  - **Default: OFF**.
  - When toggled **ON**:
    - Unblocks and powers on Bluetooth (`rfkill` / `bluez` on Linux, WinRT/Win32 Bluetooth on Windows).
    - Sets broadcast alias to **"Ever Dialer PC"** with one-tap copy button.
    - Enables discoverability and pairability without timeout.
    - Enables A2DP audio sink so any connected phone can stream media (YouTube, Spotify, calls, podcasts) directly through the PC speakers.
    - Monitors connected devices in real time (shows phone name, MAC address, and streaming badge).
- **Audio Output & Unmute Integration**:
  - Checks if your master speaker is muted and provides an **Unmute** button alongside a volume slider (via PipeWire/PulseAudio on Linux and Core Audio COM APIs on Windows).

---

## 🚀 Running the App

### Via Terminal
```bash
# Run in debug mode:
flutter run -d linux      # On Linux
flutter run -d windows    # On Windows

# Package for all Linux distributions (AppImage, DEB, RPM, Arch, Tarball):
app_release
# (Or run directly from the repo: bash scripts/app_release.sh)
# Packages are automatically placed into: ~/Downloads/Linux Release/

# Build and package Windows 10 & 11 executable (.exe):
app_release_win
# (Or run directly from the repo: scripts\app_release_win.bat)
# Packages are automatically placed into: %USERPROFILE%\Downloads\Windows Release\
```

---

## 📂 Project Structure

```
├── CROSS_PLATFORM_GUIDELINES.md # Dual-boot Windows & Linux rules
├── pubspec.yaml                 # Manifest & dependencies (with mobile overrides)
├── lib/
│   ├── main.dart                # DynamicColorBuilder, M3 theme, & App Bar
│   ├── screens/                 # Setup & installer screens
│   ├── services/
│   │   ├── bluetooth_service.dart # BlueZ & PipeWire / WinRT controller
│   │   └── system_service.dart    # Cross-platform volume & window controls
│   └── widgets/
│       ├── bluetooth_container.dart # "Bluetooth Connection" M3 container
│       └── audio_status_card.dart   # Speaker volume slider & unmute card
├── test/
│   └── widget_test.dart         # Widget smoke test
├── linux/                       # Native Linux GTK desktop runner & icons
└── windows/                     # Native Windows Win32 desktop runner & icons
```

