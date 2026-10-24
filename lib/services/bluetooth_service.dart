import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSinkDevice {
  final String name;
  final String description;
  final bool isDefault;

  const AudioSinkDevice({
    required this.name,
    required this.description,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSinkDevice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          isDefault == other.isDefault;

  @override
  int get hashCode => name.hashCode ^ description.hashCode ^ isDefault.hashCode;
}

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
  final String? activeSinkName;
  final String? activeSinkDescription;
  final List<AudioSinkDevice> availableSinks;
  final bool phoneAudioProfileActive;

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
    this.activeSinkName,
    this.activeSinkDescription,
    this.availableSinks = const [],
    this.phoneAudioProfileActive = true,
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
    String? activeSinkName,
    String? activeSinkDescription,
    List<AudioSinkDevice>? availableSinks,
    bool? phoneAudioProfileActive,
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
      activeSinkName: activeSinkName ?? this.activeSinkName,
      activeSinkDescription:
          activeSinkDescription ?? this.activeSinkDescription,
      availableSinks: availableSinks ?? this.availableSinks,
      phoneAudioProfileActive:
          phoneAudioProfileActive ?? this.phoneAudioProfileActive,
    );
  }
}

class BluetoothService extends ChangeNotifier {
  static const _prefSpeakerModeKey = 'speaker_mode_enabled';

  BluetoothState _state = const BluetoothState();
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
    // Check initial saved state synchronously if prefs already provided
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

    // Query current audio state immediately so we know the system volume and mute state
    await _queryAudioState();

    if (autoRefresh) {
      if (savedEnabled) {
        // If persisted as ON, ensure hardware is active
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
    // Persist the user's explicit choice across app restarts
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_prefSpeakerModeKey, enable);

    _state = _state.copyWith(
      speakerModeEnabled: enable,
      statusMessage: enable
          ? 'Starting Bluetooth Speaker...'
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

        // 3. Keep default PC name (do NOT change system alias)

        // 4. Make discoverable & pairable without timeout
        await Process.run('bluetoothctl', ['discoverable-timeout', '0']);
        await Process.run('bluetoothctl', ['discoverable', 'on']);
        await Process.run('bluetoothctl', ['pairable', 'on']);

        // 5. Ensure device is trusted and audio profile is active if already connected
        if (_state.connectedDevice != null) {
          await Process.run('bluetoothctl', ['trust', _state.connectedDevice!.mac]);
          await _ensureBluezProfileActive();
        }

        _state = _state.copyWith(
          powered: true,
          discoverable: true,
          pairable: true,
          statusMessage: 'Discoverable: Phone can connect to ${_state.alias}',
        );
      } catch (e) {
        _state = _state.copyWith(statusMessage: 'Error enabling speaker: $e');
      }
    } else {
      // Return Bluetooth configuration back to normal stage
      try {
        // 1. Disconnect any connected mobile device
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

  Future<void> setOutputSink(String sinkName) async {
    try {
      await Process.run('pactl', ['set-default-sink', sinkName]);
      await refresh();
    } catch (_) {}
  }

  Future<void> repairAudioRouting() async {
    _state = _state.copyWith(statusMessage: 'Repairing PipeWire audio routing...');
    notifyListeners();

    try {
      // 1. Unblock bluetooth and power on
      await Process.run('rfkill', ['unblock', 'bluetooth']);
      await Process.run('bluetoothctl', ['power', 'on']);
      await Process.run('bluetoothctl', ['discoverable-timeout', '0']);
      await Process.run('bluetoothctl', ['discoverable', 'on']);
      await Process.run('bluetoothctl', ['pairable', 'on']);

      // 2. Trust connected device if any
      if (_state.connectedDevice != null) {
        await Process.run('bluetoothctl', ['trust', _state.connectedDevice!.mac]);
      }

      // 3. Restore bluez profile to audio-gateway
      await _ensureBluezProfileActive();

      // 4. Ensure Laptop Speakers is default if currently defaulting to silent HDMI
      try {
        final defRes = await Process.run('pactl', ['get-default-sink']);
        final currentDef = (defRes.stdout as String).trim();
        if (currentDef.toLowerCase().contains('hdmi')) {
          final sinksRes = await Process.run('pactl', ['-f', 'json', 'list', 'sinks']);
          if (sinksRes.exitCode == 0) {
            final sinksList = jsonDecode(sinksRes.stdout as String) as List<dynamic>;
            for (final s in sinksList) {
              final sMap = s as Map<String, dynamic>;
              final name = sMap['name'] as String? ?? '';
              if (name.toLowerCase().contains('speaker')) {
                await Process.run('pactl', ['set-default-sink', name]);
                break;
              }
            }
          }
        }
      } catch (_) {}

      // 5. Unmute default sink only if user has not set volume to 0
      if (_state.speakerVolume > 0) {
        await Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', '0']);
        if (_state.speakerVolume < 0.2) {
          await setVolume(0.75);
        }
      }

      _state = _state.copyWith(
        statusMessage: 'Audio routing repaired! Speakers active.',
        phoneAudioProfileActive: true,
      );
    } catch (e) {
      _state = _state.copyWith(statusMessage: 'Error repairing audio: $e');
    }

    await refresh();
  }

  Future<void> _ensureBluezProfileActive() async {
    try {
      final cardsRes = await Process.run('pactl', ['-f', 'json', 'list', 'cards']);
      if (cardsRes.exitCode == 0) {
        final cardsList = jsonDecode(cardsRes.stdout as String) as List<dynamic>;
        for (final c in cardsList) {
          final cMap = c as Map<String, dynamic>;
          final name = cMap['name'] as String? ?? '';
          if (name.startsWith('bluez_card.')) {
            final profiles = cMap['profiles'] as Map<String, dynamic>? ?? {};
            String? targetProfile;
            if (profiles.containsKey('audio-gateway')) {
              targetProfile = 'audio-gateway';
            } else if (profiles.containsKey('a2dp-source')) {
              targetProfile = 'a2dp-source';
            }
            if (targetProfile != null) {
              await Process.run('pactl', ['set-card-profile', name, targetProfile]);
            }
          }
        }
      }
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
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              alias = parts[1].trim();
            }
          } else if (trimmed.startsWith('Name:')) {
            final parts = trimmed.split('Name:');
            if (parts.length > 1 && (alias.isEmpty || alias == 'Ever Dialer PC')) {
              alias = parts[1].trim();
            }
          }
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
                // Ensure device is trusted so BlueZ doesn't drop incoming audio streams
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
      // 1. Query volume and mute state
      final volResult = await Process.run(
        'wpctl',
        ['get-volume', '@DEFAULT_AUDIO_SINK@'],
      );
      bool isMuted = _state.speakerMuted;
      double volume = _state.speakerVolume;

      if (volResult.exitCode == 0) {
        final text = (volResult.stdout as String).trim();
        isMuted = text.contains('[MUTED]');
        final parts = text.split(RegExp(r'\s+'));
        for (final part in parts) {
          final parsed = double.tryParse(part);
          if (parsed != null) {
            volume = parsed;
            break;
          }
        }
      }

      // 2. Query available sinks
      String? defaultSinkName;
      try {
        final defRes = await Process.run('pactl', ['get-default-sink']);
        if (defRes.exitCode == 0) {
          defaultSinkName = (defRes.stdout as String).trim();
        }
      } catch (_) {}

      final List<AudioSinkDevice> sinks = [];
      String? activeSinkDescription;

      try {
        final sinksRes = await Process.run('pactl', ['-f', 'json', 'list', 'sinks']);
        if (sinksRes.exitCode == 0) {
          final sinksList = jsonDecode(sinksRes.stdout as String) as List<dynamic>;
          for (final s in sinksList) {
            final sMap = s as Map<String, dynamic>;
            final name = sMap['name'] as String? ?? '';
            final desc = sMap['description'] as String? ?? name;
            final isDef = name == defaultSinkName;
            if (isDef) {
              activeSinkDescription = desc;
            }
            sinks.add(AudioSinkDevice(
              name: name,
              description: desc,
              isDefault: isDef,
            ));
          }
        }
      } catch (_) {}

      // 3. Check if phone's bluez card profile is active (not 'off')
      bool phoneProfileActive = true;
      try {
        final cardsRes = await Process.run('pactl', ['-f', 'json', 'list', 'cards']);
        if (cardsRes.exitCode == 0) {
          final cardsList = jsonDecode(cardsRes.stdout as String) as List<dynamic>;
          for (final c in cardsList) {
            final cMap = c as Map<String, dynamic>;
            final name = cMap['name'] as String? ?? '';
            if (name.startsWith('bluez_card.')) {
              final activeProfile = cMap['active_profile'] as String? ?? '';
              if (activeProfile == 'off') {
                phoneProfileActive = false;
                // Auto-restore audio-gateway profile if speaker mode is enabled
                if (_state.speakerModeEnabled && _state.connectedDevice != null) {
                  final profiles = cMap['profiles'] as Map<String, dynamic>? ?? {};
                  String? targetProfile;
                  if (profiles.containsKey('audio-gateway')) {
                    targetProfile = 'audio-gateway';
                  } else if (profiles.containsKey('a2dp-source')) {
                    targetProfile = 'a2dp-source';
                  }
                  if (targetProfile != null) {
                    await Process.run('pactl', ['set-card-profile', name, targetProfile]);
                    phoneProfileActive = true;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      _state = _state.copyWith(
        speakerMuted: isMuted,
        speakerVolume: volume,
        activeSinkName: defaultSinkName,
        activeSinkDescription: activeSinkDescription,
        availableSinks: sinks,
        phoneAudioProfileActive: phoneProfileActive,
      );
    } catch (_) {}
  }
}
