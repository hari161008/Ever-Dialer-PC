import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothDevice {
  final String mac;
  final String name;
  final bool connected;

  BluetoothDevice({
    required this.mac,
    required this.name,
    required this.connected,
  });
}

class BluetoothState {
  final bool powered;
  final bool discoverable;
  final bool pairable;
  final String alias;
  final BluetoothDevice? connectedDevice;
  final bool speakerModeEnabled;
  final bool speakerMuted;
  final double speakerVolume;
  final String statusMessage;

  const BluetoothState({
    this.powered = false,
    this.discoverable = false,
    this.pairable = false,
    this.alias = 'fedora',
    this.connectedDevice,
    this.speakerModeEnabled = false,
    this.speakerMuted = false,
    this.speakerVolume = 0.5,
    this.statusMessage = 'Ready',
  });

  BluetoothState copyWith({
    bool? powered,
    bool? discoverable,
    bool? pairable,
    String? alias,
    BluetoothDevice? connectedDevice,
    bool clearConnectedDevice = false,
    bool? speakerModeEnabled,
    bool? speakerMuted,
    double? speakerVolume,
    String? statusMessage,
  }) {
    return BluetoothState(
      powered: powered ?? this.powered,
      discoverable: discoverable ?? this.discoverable,
      pairable: pairable ?? this.pairable,
      alias: alias ?? this.alias,
      connectedDevice: clearConnectedDevice
          ? null
          : (connectedDevice ?? this.connectedDevice),
      speakerModeEnabled: speakerModeEnabled ?? this.speakerModeEnabled,
      speakerMuted: speakerMuted ?? this.speakerMuted,
      speakerVolume: speakerVolume ?? this.speakerVolume,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class BluetoothService extends ChangeNotifier {
  static const _prefSpeakerModeKey = 'speaker_mode_enabled';

  BluetoothState _state = BluetoothState(alias: Platform.localHostname);
  Timer? _pollTimer;
  SharedPreferences? _prefs;

  bool? _originalPowered;

  BluetoothState get state => _state;

  BluetoothService({
    bool autoStartTimer = true,
    bool autoRefresh = true,
    SharedPreferences? prefs,
  }) {
    _prefs = prefs;
    if (_prefs != null) {
      final saved = _prefs!.getBool(_prefSpeakerModeKey) ?? false;
      _state = _state.copyWith(speakerModeEnabled: saved);
    }
    _init(autoStartTimer, autoRefresh);
  }

  Future<void> _init(bool autoStartTimer, bool autoRefresh) async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedEnabled = _prefs?.getBool(_prefSpeakerModeKey) ?? false;

    if (savedEnabled != _state.speakerModeEnabled) {
      _state = _state.copyWith(speakerModeEnabled: savedEnabled);
      notifyListeners();
    }

    if (autoRefresh) {
      if (savedEnabled) {
        await _applySpeakerHardware(true);
      }
      await refresh();
    }

    if (autoStartTimer) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        refresh();
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> toggleSpeakerMode(bool enable) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_prefSpeakerModeKey, enable);

    _state = _state.copyWith(
      speakerModeEnabled: enable,
      statusMessage: enable
          ? 'Enabling Bluetooth Speaker...'
          : 'Restoring Bluetooth...',
    );
    notifyListeners();

    if (enable) {
      await _applySpeakerHardware(true);
    } else {
      await _applySpeakerHardware(false);
    }

    notifyListeners();
    await refresh();
  }

  Future<void> _applySpeakerHardware(bool enable) async {
    if (enable) {
      try {
        _originalPowered ??= _state.powered;

        // 1. Unblock rfkill if blocked
        await Process.run('rfkill', ['unblock', 'bluetooth']);

        // 2. Power on bluetooth
        await Process.run('bluetoothctl', ['power', 'on']);

        // 3. Make discoverable & pairable without timeout
        await Process.run('bluetoothctl', ['discoverable-timeout', '0']);
        await Process.run('bluetoothctl', ['discoverable', 'on']);
        await Process.run('bluetoothctl', ['pairable', 'on']);

        // 4. Ensure speakers are unmuted
        await Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', '0']);

        _state = _state.copyWith(
          powered: true,
          discoverable: true,
          pairable: true,
          statusMessage: 'Discoverable as ${_state.alias}',
        );
      } catch (e) {
        _state = _state.copyWith(statusMessage: 'Error enabling speaker: $e');
      }
    } else {
      // Return Bluetooth configuration back to normal stage
      try {
        // 1. Disconnect any active media streaming device
        if (_state.connectedDevice != null) {
          await Process.run(
            'bluetoothctl',
            ['disconnect', _state.connectedDevice!.mac],
          );
        }

        // 2. Turn off discoverability
        await Process.run('bluetoothctl', ['discoverable', 'off']);

        // 3. Reset discoverable timeout back to standard 180 seconds
        await Process.run('bluetoothctl', ['discoverable-timeout', '180']);

        // 4. If Bluetooth was originally powered off, restore power off
        if (_originalPowered == false) {
          await Process.run('bluetoothctl', ['power', 'off']);
        }

        _state = _state.copyWith(
          discoverable: false,
          clearConnectedDevice: true,
          statusMessage: 'Bluetooth restored to normal state',
        );
      } catch (e) {
        _state = _state.copyWith(
          statusMessage: 'Error restoring normal stage: $e',
        );
      }
    }
  }

  Future<void> unmuteSpeaker() async {
    try {
      await Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', '0']);
      await _queryAudioState();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    try {
      final clamped = volume.clamp(0.0, 1.5);
      await Process.run(
        'wpctl',
        ['set-volume', '@DEFAULT_AUDIO_SINK@', clamped.toStringAsFixed(2)],
      );
      _state = _state.copyWith(speakerVolume: clamped);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disconnectDevice(String mac) async {
    try {
      await Process.run('bluetoothctl', ['disconnect', mac]);
      await refresh();
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _queryBluetoothState();
    await _queryAudioState();
    notifyListeners();
  }

  Future<void> _queryBluetoothState() async {
    try {
      final showResult = await Process.run('bluetoothctl', ['show']);
      if (showResult.exitCode == 0) {
        final text = showResult.stdout as String;
        bool powered = false;
        bool discoverable = false;
        bool pairable = false;
        String alias = _state.alias;

        for (final line in text.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('Powered:')) {
            powered = trimmed.endsWith('yes');
          } else if (trimmed.startsWith('Discoverable:')) {
            discoverable = trimmed.endsWith('yes');
          } else if (trimmed.startsWith('Pairable:')) {
            pairable = trimmed.endsWith('yes');
          } else if (trimmed.startsWith('Alias:')) {
            final parts = trimmed.split('Alias:');
            if (parts.length > 1) {
              final found = parts[1].trim();
              if (found.isNotEmpty) {
                alias = found;
              }
            }
          }
        }

        if (!_state.speakerModeEnabled) {
          _originalPowered ??= powered;
        }

        // Check for connected devices
        BluetoothDevice? connectedDevice;
        final devResult = await Process.run(
          'bluetoothctl',
          ['devices', 'Connected'],
        );
        if (devResult.exitCode == 0) {
          final devText = (devResult.stdout as String).trim();
          if (devText.isNotEmpty) {
            final devLines = devText.split('\n');
            for (final dLine in devLines) {
              final tokens = dLine.trim().split(RegExp(r'\s+'));
              if (tokens.length >= 3 && tokens[0] == 'Device') {
                final mac = tokens[1];
                final name = tokens.sublist(2).join(' ');
                connectedDevice = BluetoothDevice(
                  mac: mac,
                  name: name,
                  connected: true,
                );

                // Auto-trust connected device so future connections are seamless
                Process.run('bluetoothctl', ['trust', mac]);
                break;
              }
            }
          }
        }

        _state = _state.copyWith(
          powered: powered,
          discoverable: discoverable,
          pairable: pairable,
          alias: alias,
          connectedDevice: connectedDevice,
          clearConnectedDevice: connectedDevice == null,
        );
      }
    } catch (_) {}
  }

  Future<void> _queryAudioState() async {
    try {
      final volResult = await Process.run(
        'wpctl',
        ['get-volume', '@DEFAULT_AUDIO_SINK@'],
      );
      if (volResult.exitCode == 0) {
        final text = (volResult.stdout as String).trim();
        final isMuted = text.contains('[MUTED]');
        double volume = _state.speakerVolume;

        final parts = text.split(RegExp(r'\s+'));
        for (final part in parts) {
          final parsed = double.tryParse(part);
          if (parsed != null) {
            volume = parsed;
            break;
          }
        }

        _state = _state.copyWith(
          speakerMuted: isMuted,
          speakerVolume: volume,
        );
      }
    } catch (_) {}
  }
}
