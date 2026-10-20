import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../widgets/bluetooth_container.dart';
import '../widgets/audio_status_card.dart';

class SettingsScreen extends StatelessWidget {
  final BluetoothService bluetoothService;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.bluetoothService,
    required this.themeMode,
    required this.onToggleTheme,
  });

  IconData _getThemeIcon() {
    switch (themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeLabel() {
    switch (themeMode) {
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.system:
        return 'System Dynamic (KDE)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_getThemeIcon(), color: colorScheme.onSurfaceVariant),
            tooltip: _getThemeLabel(),
            onPressed: onToggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
            tooltip: 'Refresh Hardware Status',
            onPressed: () {
              bluetoothService.refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hardware state refreshed'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: bluetoothService,
        builder: (context, _) {
          final state = bluetoothService.state;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Primary Container: "Bluetooth Connection"
                BluetoothContainer(
                  state: state,
                  onToggle: (enable) => bluetoothService.toggleSpeakerMode(enable),
                  onDisconnect: (mac) => bluetoothService.disconnectDevice(mac),
                ),

                const SizedBox(height: 18),

                // 2. Audio Output & Unmute Card
                AudioStatusCard(
                  state: state,
                  onUnmute: () => bluetoothService.unmuteSpeaker(),
                  onVolumeChanged: (vol) => bluetoothService.setVolume(vol),
                ),

                const SizedBox(height: 18),

                // 3. Theme & Appearance Card
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getThemeIcon(),
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance Theme',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _getThemeLabel(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: onToggleTheme,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Footer Info
                Center(
                  child: Text(
                    'PipeWire A2DP Audio Sink • BlueZ 5 • Fedora Linux',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}
