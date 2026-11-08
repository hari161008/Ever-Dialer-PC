import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.everdialer.ever_dialer_pc/system');

  final SharedPreferences? prefs;
  bool _autostartEnabled = true;
  bool _systemTrayEnabled = true;
  bool _exitOnClose = false;
  bool _isMaximized = false;

  bool get autostartEnabled => _autostartEnabled;
  bool get systemTrayEnabled => _systemTrayEnabled;
  bool get exitOnClose => _exitOnClose;
  bool get isMaximized => _isMaximized;

  Future<void> minimizeWindow() async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('minimizeWindow');
      }
    } catch (e) {
      debugPrint('[SystemService] Error minimizing window: $e');
    }
  }

  Future<void> toggleMaximizeWindow() async {
    try {
      if (Platform.isLinux) {
        final res = await _channel.invokeMethod<bool>('toggleMaximizeWindow');
        _isMaximized = res ?? !_isMaximized;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SystemService] Error toggling maximize: $e');
    }
  }

  Future<void> closeWindow() async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('closeWindow');
      }
      if (_exitOnClose) {
        exit(0);
      }
    } catch (e) {
      debugPrint('[SystemService] Error closing window: $e');
      if (_exitOnClose) {
        exit(0);
      }
    }
  }

  int _lastDragCallTime = 0;

  Future<void> startWindowDrag() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDragCallTime < 150) return;
    _lastDragCallTime = now;
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('startDrag');
      }
    } catch (e) {
      debugPrint('[SystemService] Error starting window drag: $e');
    }
  }

  int _lastResizeCallTime = 0;

  Future<void> startWindowResize(String edge) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastResizeCallTime < 100) return;
    _lastResizeCallTime = now;
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('startResize', {'edge': edge});
      }
    } catch (e) {
      debugPrint('[SystemService] Error starting window resize: $e');
    }
  }

  static Future<void> startResize(String edge) async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('startResize', {'edge': edge});
      }
    } catch (e) {
      debugPrint('[SystemService] Error starting static window resize: $e');
    }
  }

  int _pcVolume = 50;
  bool _pcMuted = false;

  int get pcVolume => _pcVolume;
  bool get pcMuted => _pcMuted;

  SystemService({this.prefs}) {
    _loadSettings();
    refreshPcVolume();
  }

  Future<void> refreshPcVolume() async {
    try {
      if (Platform.isLinux) {
        final res = await Process.run('pactl', ['get-sink-volume', '@DEFAULT_SINK@']);
        if (res.exitCode == 0) {
          final match = RegExp(r'(\d+)%').firstMatch(res.stdout.toString());
          if (match != null) {
            _pcVolume = int.tryParse(match.group(1) ?? '50') ?? _pcVolume;
          }
        }
        final muteRes = await Process.run('pactl', ['get-sink-mute', '@DEFAULT_SINK@']);
        if (muteRes.exitCode == 0) {
          _pcMuted = muteRes.stdout.toString().toLowerCase().contains('yes');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SystemService] Error refreshing PC volume: $e');
    }
  }

  Future<void> setPcVolume(int volume) async {
    _pcVolume = volume.clamp(0, 100);
    notifyListeners();
    try {
      if (Platform.isLinux) {
        await Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '$_pcVolume%']);
      }
    } catch (e) {
      debugPrint('[SystemService] Error setting PC volume: $e');
    }
  }

  Future<void> togglePcMute() async {
    _pcMuted = !_pcMuted;
    notifyListeners();
    try {
      if (Platform.isLinux) {
        await Process.run('pactl', ['set-sink-mute', '@DEFAULT_SINK@', _pcMuted ? '1' : '0']);
      }
    } catch (e) {
      debugPrint('[SystemService] Error toggling PC mute: $e');
    }
  }

  void _loadSettings() {
    _autostartEnabled = prefs?.getBool('autostart_enabled') ?? true;
    _systemTrayEnabled = prefs?.getBool('system_tray_enabled') ?? true;
    _exitOnClose = prefs?.getBool('exit_on_close') ?? false;
    _applyAutostart(_autostartEnabled);
    _applySystemTray(_systemTrayEnabled);
    _applyExitOnClose(_exitOnClose);
  }

  Future<void> setAutostartEnabled(bool enabled) async {
    _autostartEnabled = enabled;
    notifyListeners();
    await prefs?.setBool('autostart_enabled', enabled);
    await _applyAutostart(enabled);
  }

  Future<void> setExitOnClose(bool enabled) async {
    _exitOnClose = enabled;
    notifyListeners();
    await prefs?.setBool('exit_on_close', enabled);
    await _applyExitOnClose(enabled);
  }

  Future<void> setSystemTrayEnabled(bool enabled) async {
    _systemTrayEnabled = enabled;
    notifyListeners();
    await prefs?.setBool('system_tray_enabled', enabled);
    await _applySystemTray(enabled);
  }

  Future<void> _applyExitOnClose(bool enabled) async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('setExitOnClose', {'enabled': enabled});
      }
    } catch (e) {
      debugPrint('[SystemService] Error applying exit on close: $e');
    }
  }

  Future<void> _applyAutostart(bool enabled) async {
    try {
      if (!Platform.isLinux) return;
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;
      final autostartDir = Directory('$home/.config/autostart');
      final desktopFile = File('${autostartDir.path}/ever_dialer_pc.desktop');

      if (enabled) {
        if (!await autostartDir.exists()) {
          await autostartDir.create(recursive: true);
        }
        final exePath = Platform.resolvedExecutable;
        final content = '''[Desktop Entry]
Type=Application
Name=Ever Dialer PC
Comment=Bluetooth Media Speaker Sink & Phone Companion
Exec="$exePath" --hidden
Icon=ever_dialer_pc
Terminal=false
Categories=AudioVideo;Audio;Utility;
StartupWMClass=ever_dialer_pc
X-GNOME-Autostart-enabled=true
''';
        await desktopFile.writeAsString(content);
      } else {
        if (await desktopFile.exists()) {
          await desktopFile.delete();
        }
      }
    } catch (e) {
      debugPrint('[SystemService] Error applying autostart: $e');
    }
  }

  Future<void> _applySystemTray(bool enabled) async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod('setSystemTray', {'enabled': enabled});
      }
    } catch (e) {
      // Channel might not be registered in tests or on unsupported platforms
      debugPrint('[SystemService] Error applying system tray: $e');
    }
  }

  Future<String?> detectSystemPackage() async {
    try {
      if (!Platform.isLinux) return null;
      // 1. RPM (Fedora, RHEL, openSUSE)
      final rpmCheck = await Process.run('bash', ['-c', 'command -v rpm >/dev/null 2>&1 && rpm -q ever-dialer-pc >/dev/null 2>&1']);
      if (rpmCheck.exitCode == 0) return 'RPM Package (Fedora / RHEL / openSUSE)';

      // 2. DEB (Debian, Ubuntu, Linux Mint, Pop!_OS)
      final debCheck = await Process.run('bash', ['-c', 'command -v dpkg >/dev/null 2>&1 && dpkg -s ever-dialer-pc >/dev/null 2>&1']);
      if (debCheck.exitCode == 0) return 'DEB Package (Debian / Ubuntu / Mint / Pop!_OS)';

      // 3. Arch Linux / Manjaro / EndeavourOS
      final archCheck = await Process.run('bash', ['-c', 'command -v pacman >/dev/null 2>&1 && pacman -Q ever-dialer-pc >/dev/null 2>&1']);
      if (archCheck.exitCode == 0) return 'Arch Linux Package (pacman)';

      // 4. Flatpak
      final flatpakCheck = await Process.run('bash', ['-c', 'command -v flatpak >/dev/null 2>&1 && flatpak info com.everdialer.ever_dialer_pc >/dev/null 2>&1']);
      if (flatpakCheck.exitCode == 0) return 'Flatpak Package';

      // 5. Snap
      final snapCheck = await Process.run('bash', ['-c', 'command -v snap >/dev/null 2>&1 && snap list ever-dialer-pc >/dev/null 2>&1']);
      if (snapCheck.exitCode == 0) return 'Snap Package';

      // 6. Manual root files in /opt or /usr
      final sysFilesCheck = await Process.run('bash', ['-c', '[ -d "/opt/ever_dialer_pc" ] || [ -f "/usr/bin/ever_dialer_pc" ] || [ -f "/usr/local/bin/ever_dialer_pc" ] || [ -f "/usr/share/applications/ever_dialer_pc.desktop" ]']);
      if (sysFilesCheck.exitCode == 0) return 'System Root Files (/opt or /usr)';

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkRpmInstalled() async => (await detectSystemPackage()) != null;

  Future<bool> removeSystemPackage() async {
    try {
      if (!Platform.isLinux) return false;
      final res = await Process.run('bash', [
        '-c',
        '''
if command -v rpm >/dev/null 2>&1 && rpm -q ever-dialer-pc >/dev/null 2>&1; then
  pkexec rpm -e ever-dialer-pc || pkexec dnf remove -y ever-dialer-pc 2>/dev/null || true
elif command -v dpkg >/dev/null 2>&1 && dpkg -s ever-dialer-pc >/dev/null 2>&1; then
  pkexec apt-get remove -y ever-dialer-pc || pkexec dpkg -r ever-dialer-pc 2>/dev/null || true
elif command -v pacman >/dev/null 2>&1 && pacman -Q ever-dialer-pc >/dev/null 2>&1; then
  pkexec pacman -R --noconfirm ever-dialer-pc 2>/dev/null || true
elif command -v flatpak >/dev/null 2>&1 && flatpak info com.everdialer.ever_dialer_pc >/dev/null 2>&1; then
  flatpak uninstall -y com.everdialer.ever_dialer_pc 2>/dev/null || true
elif command -v snap >/dev/null 2>&1 && snap list ever-dialer-pc >/dev/null 2>&1; then
  pkexec snap remove ever-dialer-pc 2>/dev/null || true
fi

# Clean any leftover system root directories/binaries if they exist
if [ -d "/opt/ever_dialer_pc" ] || [ -f "/usr/bin/ever_dialer_pc" ] || [ -f "/usr/local/bin/ever_dialer_pc" ] || [ -f "/usr/share/applications/ever_dialer_pc.desktop" ]; then
  pkexec rm -rf /opt/ever_dialer_pc /usr/bin/ever_dialer_pc /usr/local/bin/ever_dialer_pc /usr/share/applications/ever_dialer_pc.desktop /usr/share/icons/hicolor/*/apps/ever_dialer_pc.png 2>/dev/null || true
fi
'''
      ]);
      return res.exitCode == 0;
    } catch (e) {
      debugPrint('[SystemService] Error removing system package: $e');
      return false;
    }
  }

  Future<bool> removeRpmPackage() => removeSystemPackage();

  Future<void> performUninstall({bool deleteSource = false, bool removeRpm = true, bool removeSysPackage = true}) async {
    try {
      if (!Platform.isLinux) return;
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return;

      // 1. Terminate sync daemon
      try {
        await Process.run('pkill', ['-f', 'bt_sync_daemon.py']);
      } catch (e) {
        debugPrint('[SystemService] Error killing daemon: $e');
      }

      // 1.5 If a system package/root installation is detected, remove it using pkexec
      if ((removeSysPackage || removeRpm) && (await detectSystemPackage()) != null) {
        await removeSystemPackage();
      }

      // 2. Remove desktop shortcuts, symlinks, and autostart entries
      try {
        await Process.run('bash', [
          '-c',
          '''
rm -f "$home/.local/share/applications/ever_dialer_pc.desktop"
rm -f "$home/.local/share/applications/com.everdialer.ever_dialer_pc.desktop"
rm -f "$home/.config/autostart/ever_dialer_pc.desktop"
rm -f /tmp/everdialer_bt_sync.lock

# If a system-wide desktop entry exists in /usr/share/applications, mask it
# so it does not unmask and show up in the application drawer
if [ -f "/usr/share/applications/ever_dialer_pc.desktop" ] || [ -f "/usr/local/share/applications/ever_dialer_pc.desktop" ]; then
  cat << 'EOF' > "$home/.local/share/applications/ever_dialer_pc.desktop"
[Desktop Entry]
Type=Application
Name=Ever Dialer PC
NoDisplay=true
Hidden=true
EOF
  cat << 'EOF' > "$home/.local/share/applications/com.everdialer.ever_dialer_pc.desktop"
[Desktop Entry]
Type=Application
Name=Ever Dialer PC
NoDisplay=true
Hidden=true
EOF
fi

# Refresh desktop application databases and caches
update-desktop-database "$home/.local/share/applications" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
rm -f "$home/.local/share/icons/hicolor/"*/apps/ever_dialer_pc.png 2>/dev/null || true
gtk-update-icon-cache "$home/.local/share/icons/hicolor" 2>/dev/null || true
'''
        ]);
      } catch (e) {
        debugPrint('[SystemService] Error cleaning desktop entries: $e');
      }

      // 4. Remove local app cache, preferences and data
      final dirsToDelete = [
        '$home/.local/share/com.everdialer.ever_dialer_pc',
        '$home/.config/ever_dialer_pc',
      ];
      for (final p in dirsToDelete) {
        final d = Directory(p);
        if (await d.exists()) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }

      // 5. Delete source code / build directory if requested
      if (deleteSource) {
        final projectDir = Directory.current.path;
        if (projectDir.isNotEmpty && projectDir != '/' && projectDir != home) {
          await Process.run('bash', [
            '-c',
            'nohup sh -c "sleep 1 && rm -rf \\"$projectDir\\"" >/dev/null 2>&1 &'
          ]);
        }
      }

      // 6. Show desktop notification
      try {
        await Process.run('notify-send', [
          'Ever Dialer PC',
          'Ever Dialer PC uninstalled successfully.',
          '-i',
          'dialog-information',
        ]);
      } catch (_) {}

      // 7. Exit app cleanly
      exit(0);
    } catch (e) {
      debugPrint('[SystemService] Error performing uninstall: $e');
      rethrow;
    }
  }
}
