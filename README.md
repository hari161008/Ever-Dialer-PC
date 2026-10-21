# Ever Dialer PC 📱🔊

A native Linux desktop application built with **Flutter & Dart** for Fedora, featuring **Android Material You (Material 3)** dynamic theming and a **Bluetooth Connection** container that turns your PC into a wireless media speaker for your phone.

---

## ✨ Features

- **Android Material You (Material 3) Design**:
  - Powered by Flutter's native Material 3 design system with `dynamic_color`.
  - Automatically queries and applies your KDE/system accent color (e.g. Amber/Gold `#FFDD31`) with full dynamic tonal mapping (Primary, Surface, Surface Container, On-Primary, etc.).
  - Smooth animated **M3 Switch** with pill track and sliding thumb with checkmark glyph.
  - Large rounded squircle cards (28dp radii), full-pill chips, and interactive 3-step phone pairing guide.
  - System, Dark, and Light mode dynamic switching with instant hot reload.
- **Bluetooth Connection Container**:
  - **Default: OFF**.
  - When toggled **ON**:
    - Unblocks and powers on Bluetooth (`rfkill` / `bluez`).
    - Sets broadcast alias to **"Ever Dialer PC"** with one-tap copy button.
    - Enables discoverability and pairability without timeout.
    - Enables PipeWire A2DP audio sink so any connected phone can stream media (YouTube, Spotify, calls, podcasts) directly through the PC speakers.
    - Monitors connected devices in real time (shows phone name, MAC address, and streaming badge).
- **Audio Output & Unmute Integration**:
  - Checks if your Fedora / PipeWire master speaker is muted and provides an **Unmute** button alongside a volume slider.

---

## 🚀 Running the App

### Via Terminal
```bash
# Run on Linux desktop
flutter run -d linux

# Or build release
flutter build linux
./build/linux/x64/release/bundle/ever_dialer_pc

# Package for all Linux distributions (AppImage, DEB, RPM, Arch, Tarball)
build_release
# (Or run directly from the repo: bash scripts/build_release.sh)
# Packages are automatically placed into: ~/Downloads/Linux Release/
```

## 📂 Project Structure

```
├── pubspec.yaml                # Project manifest and dependencies
├── lib/
│   ├── main.dart               # DynamicColorBuilder, M3 theme, & App Bar
│   ├── services/
│   │   └── bluetooth_service.dart # BlueZ & PipeWire background controller
│   └── widgets/
│       ├── bluetooth_container.dart # "Bluetooth Connection" M3 container
│       └── audio_status_card.dart   # Speaker volume slider & unmute card
├── test/
│   └── widget_test.dart        # Widget smoke test
└── linux/                      # Native Linux GTK desktop runner
```
