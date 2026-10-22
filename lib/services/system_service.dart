import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.everdialer.ever_dialer_pc/system');

  final SharedPreferences? prefs;
  bool _autostartEnabled = true;
  bool _systemTrayEnabled = true;

  bool get autostartEnabled => _autostartEnabled;
  bool get systemTrayEnabled => _systemTrayEnabled;

  SystemService({this.prefs}) {
    _loadSettings();
  }

  void _loadSettings() {
    _autostartEnabled = prefs?.getBool('autostart_enabled') ?? true;
    _systemTrayEnabled = prefs?.getBool('system_tray_enabled') ?? true;
    _applyAutostart(_autostartEnabled);
    _applySystemTray(_systemTrayEnabled);
  }

  Future<void> setAutostartEnabled(bool enabled) async {
    _autostartEnabled = enabled;
    notifyListeners();
    await prefs?.setBool('autostart_enabled', enabled);
    await _applyAutostart(enabled);
  }

  Future<void> setSystemTrayEnabled(bool enabled) async {
    _systemTrayEnabled = enabled;
    notifyListeners();
    await prefs?.setBool('system_tray_enabled', enabled);
    await _applySystemTray(enabled);
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
Exec="$exePath"
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
}
