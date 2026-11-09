#!/bin/bash
set -e

echo "=========================================="
echo "    Ever Dialer PC - Universal Uninstaller"
echo "=========================================="

echo "[1/6] Stopping running Ever Dialer processes and background sync daemon..."
pkill -f ever_dialer_pc 2>/dev/null || true
pkill -f bt_sync_daemon.py 2>/dev/null || true

echo "[2/6] Checking for system package installations across distributions..."
# 1. RPM (Fedora, RHEL, openSUSE)
if command -v rpm >/dev/null 2>&1 && rpm -q ever-dialer-pc >/dev/null 2>&1; then
  echo "Detected RPM package 'ever-dialer-pc'. Removing package..."
  if command -v pkexec >/dev/null 2>&1; then
    pkexec rpm -e ever-dialer-pc || sudo dnf remove -y ever-dialer-pc 2>/dev/null || true
  else
    sudo dnf remove -y ever-dialer-pc 2>/dev/null || true
  fi
# 2. DEB (Debian, Ubuntu, Linux Mint, Pop!_OS)
elif command -v dpkg >/dev/null 2>&1 && dpkg -s ever-dialer-pc >/dev/null 2>&1; then
  echo "Detected DEB package 'ever-dialer-pc'. Removing package..."
  if command -v pkexec >/dev/null 2>&1; then
    pkexec apt-get remove -y ever-dialer-pc || pkexec dpkg -r ever-dialer-pc 2>/dev/null || true
  else
    sudo apt-get remove -y ever-dialer-pc 2>/dev/null || true
  fi
# 3. Arch Linux / Manjaro / EndeavourOS (pacman)
elif command -v pacman >/dev/null 2>&1 && pacman -Q ever-dialer-pc >/dev/null 2>&1; then
  echo "Detected Arch Linux package 'ever-dialer-pc'. Removing package..."
  if command -v pkexec >/dev/null 2>&1; then
    pkexec pacman -R --noconfirm ever-dialer-pc 2>/dev/null || true
  else
    sudo pacman -R --noconfirm ever-dialer-pc 2>/dev/null || true
  fi
# 4. Flatpak
elif command -v flatpak >/dev/null 2>&1 && flatpak info com.everdialer.ever_dialer_pc >/dev/null 2>&1; then
  echo "Detected Flatpak installation. Removing..."
  flatpak uninstall -y com.everdialer.ever_dialer_pc 2>/dev/null || true
# 5. Snap
elif command -v snap >/dev/null 2>&1 && snap list ever-dialer-pc >/dev/null 2>&1; then
  echo "Detected Snap installation. Removing..."
  if command -v pkexec >/dev/null 2>&1; then
    pkexec snap remove ever-dialer-pc 2>/dev/null || true
  else
    sudo snap remove ever-dialer-pc 2>/dev/null || true
  fi
fi

# Clean any leftover system root files if they exist
if [ -d "/opt/ever_dialer_pc" ] || [ -f "/usr/bin/ever_dialer_pc" ] || [ -f "/usr/local/bin/ever_dialer_pc" ] || [ -f "/usr/share/applications/ever_dialer_pc.desktop" ]; then
  echo "Cleaning leftover root files..."
  if command -v pkexec >/dev/null 2>&1; then
    pkexec rm -rf /opt/ever_dialer_pc /usr/bin/ever_dialer_pc /usr/local/bin/ever_dialer_pc /usr/share/applications/ever_dialer_pc.desktop /usr/share/icons/hicolor/*/apps/ever_dialer_pc.png 2>/dev/null || true
  else
    sudo rm -rf /opt/ever_dialer_pc /usr/bin/ever_dialer_pc /usr/local/bin/ever_dialer_pc /usr/share/applications/ever_dialer_pc.desktop /usr/share/icons/hicolor/*/apps/ever_dialer_pc.png 2>/dev/null || true
  fi
fi

echo "[3/6] Removing user desktop shortcuts, symlinks, setup wizard files, and autostart..."
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
rm -f "$DESKTOP_DIR/Ever Dialer PC.desktop"
rm -f "$DESKTOP_DIR/ever_dialer_pc.desktop"
rm -f "$HOME/Desktop/Ever Dialer PC.desktop"
rm -f "$HOME/Desktop/ever_dialer_pc.desktop"

rm -f "$HOME/.local/share/applications/ever_dialer_pc.desktop"
rm -f "$HOME/.local/share/applications/com.everdialer.ever_dialer_pc.desktop"
rm -f "$HOME/.config/autostart/ever_dialer_pc.desktop"
rm -f "$HOME/.local/bin/ever_dialer_pc"
rm -f /tmp/everdialer_bt_sync.lock

# Clean AppImage Setup Wizard user installation folder
rm -rf "$HOME/.local/share/ever_dialer_pc"
rm -rf "$HOME/.local/opt/ever_dialer_pc"

# If system desktop entry still exists after package check, mask it so it never shows in app drawer
if [ -f "/usr/share/applications/ever_dialer_pc.desktop" ] || [ -f "/usr/local/share/applications/ever_dialer_pc.desktop" ]; then
  cat << 'EOF' > "$HOME/.local/share/applications/ever_dialer_pc.desktop"
[Desktop Entry]
Type=Application
Name=Ever Dialer PC
NoDisplay=true
Hidden=true
EOF
  cat << 'EOF' > "$HOME/.local/share/applications/com.everdialer.ever_dialer_pc.desktop"
[Desktop Entry]
Type=Application
Name=Ever Dialer PC
NoDisplay=true
Hidden=true
EOF
fi

echo "[4/6] Updating desktop application database and icon caches across desktop environments..."
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
rm -f "$HOME/.local/share/icons/hicolor/"*/apps/ever_dialer_pc.png 2>/dev/null || true
rm -f "$HOME/.local/share/pixmaps/ever_dialer_pc.png" 2>/dev/null || true
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "[5/6] Removing user application cache and preferences..."
rm -rf "$HOME/.local/share/com.everdialer.ever_dialer_pc"
rm -rf "$HOME/.config/ever_dialer_pc"

echo "[6/6] Ever Dialer PC has been uninstalled successfully!"
if command -v notify-send >/dev/null 2>&1; then
    notify-send "Ever Dialer PC" "Uninstalled successfully from your system." -i dialog-information 2>/dev/null || true
fi

echo "=========================================="
