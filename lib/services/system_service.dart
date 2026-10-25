import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.everdialer.ever_dialer_pc/system');

  final SharedPreferences? prefs;
  bool _autostartEnabled = true;
  bool _systemTrayEnabled = true;
  bool _isMaximized = false;

  bool get autostartEnabled => _autostartEnabled;
  bool get systemTrayEnabled => _systemTrayEnabled;
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
    } catch (e) {
      debugPrint('[SystemService] Error closing window: $e');
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
}
