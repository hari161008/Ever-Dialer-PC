import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/sync_service.dart';
import '../services/system_service.dart';
import '../widgets/bluetooth_container.dart';
import '../widgets/audio_status_card.dart';
import '../widgets/window_header_actions.dart';

class SettingsScreen extends StatelessWidget {
  final BluetoothService bluetoothService;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final double displayScale;
  final double fontScale;
  final ValueChanged<double>? onUpdateDisplayScale;
  final ValueChanged<double>? onUpdateFontScale;
  final VoidCallback? onResetDisplayScale;
  final VoidCallback? onResetFontScale;
  final PcSyncService? syncService;
  final SystemService? systemService;

  const SettingsScreen({
    super.key,
    required this.bluetoothService,
    required this.themeMode,
    required this.onToggleTheme,
    this.displayScale = 1.0,
    this.fontScale = 1.0,
    this.onUpdateDisplayScale,
    this.onUpdateFontScale,
    this.onResetDisplayScale,
    this.onResetFontScale,
    this.syncService,
    this.systemService,
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

  Widget _buildScaleSlider({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double>? onChanged,
    required VoidCallback? onReset,
    double min = 0.8,
    double max = 1.5,
    int divisions = 14,
    String minLabel = '80%',
    String maxLabel = '150%',
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentText = '${(value * 100).round()}%';
    final isDefault = (value - 1.0).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
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
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDefault
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                percentText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDefault
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            if (!isDefault && onReset != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.restart_alt, size: 20),
                tooltip: 'Reset to 100%',
                visualDensity: VisualDensity.compact,
                onPressed: onReset,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: percentText,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              Text(
                '100% (Default)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                maxLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: WindowDragArea(
          onStartDrag: () => systemService?.startWindowDrag(),
          onDoubleTap: () => systemService?.toggleMaximizeWindow(),
          child: const SizedBox.expand(),
        ),
        title: WindowDragArea(
          onStartDrag: () => systemService?.startWindowDrag(),
          onDoubleTap: () => systemService?.toggleMaximizeWindow(),
          child: Text(
            'Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          WindowHeaderActions(
            syncService: syncService,
            systemService: systemService,
            leadingActions: [
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
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          bluetoothService,
          ?syncService,
          ?systemService,
        ]),
        builder: (context, _) {
          final state = bluetoothService.state;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Primary Unified Container: "Bluetooth Connection & Sync"
                BluetoothContainer(
                  state: state,
                  syncService: syncService,
                  onToggle: (enable) {
                    bluetoothService.toggleSpeakerMode(enable);
                    syncService?.setPcSyncEnabled(enable);
                  },
                  onDisconnect: (mac) => bluetoothService.disconnectDevice(mac),
                ),

                const SizedBox(height: 18),

                // 2. Theme & Appearance Card (below Bluetooth Connection container)
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Appearance Theme
                        Row(
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

                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),

                        // Display scale slider (0% to 200%, default 100%)
                        _buildScaleSlider(
                          context: context,
                          icon: Icons.aspect_ratio,
                          title: 'Display scale',
                          subtitle: 'UI and layout scaling',
                          value: displayScale,
                          onChanged: onUpdateDisplayScale,
                          onReset: onResetDisplayScale,
                          min: 0.0,
                          max: 2.0,
                          divisions: 40,
                          minLabel: '0%',
                          maxLabel: '200%',
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),

                        // Font scale slider
                        _buildScaleSlider(
                          context: context,
                          icon: Icons.format_size,
                          title: 'Font scale',
                          subtitle: 'Text size scaling',
                          value: fontScale,
                          onChanged: onUpdateFontScale,
                          onReset: onResetFontScale,
                          min: 0.5,
                          max: 2.0,
                          divisions: 30,
                          minLabel: '50%',
                          maxLabel: '200%',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 3. System & Startup Card
                if (systemService != null) ...[
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.power_settings_new,
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
                                      'System & Startup',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Autostart and background tray integration',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Autostart',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Launch Ever Dialer automatically when logging in',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: systemService!.autostartEnabled,
                            onChanged: (val) => systemService!.setAutostartEnabled(val),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Show in system tray',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Keep running in the system tray when window is closed',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: systemService!.systemTrayEnabled,
                            onChanged: (val) => systemService!.setSystemTrayEnabled(val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 4. Audio Output & Unmute Card
                AudioStatusCard(
                  state: state,
                  onUnmute: () => bluetoothService.unmuteSpeaker(),
                  onVolumeChanged: (vol) => bluetoothService.setVolume(vol),
                  onRepairAudio: () => bluetoothService.repairAudioRouting(),
                  onSelectSink: (sink) => bluetoothService.setOutputSink(sink),
                ),

                const SizedBox(height: 18),

                // 5. About Ever Dialer PC Card
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.dialpad,
                                  size: 30,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About Ever Dialer PC',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bluetooth Companion & Audio Sink',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info_outline, size: 12, color: colorScheme.onPrimaryContainer),
                                            const SizedBox(width: 4),
                                            Text(
                                              'v1.0.0',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified_user_outlined, size: 12, color: colorScheme.onSecondaryContainer),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Open Source',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Ever Dialer PC seamlessly connects your Linux PC with Ever Dialer Mobile over Bluetooth. Sync contacts, call logs, SMS messages, and stream high-fidelity calls or media wirelessly through your laptop speakers.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),

                        _buildAboutInfoRow(context, 'Version', 'v1.0.0'),
                        _buildAboutInfoRow(context, 'Audio Subsystem', 'PipeWire A2DP Audio Sink (BlueZ 5)'),
                        _buildAboutInfoRow(context, 'Desktop Integration', 'StatusNotifierItem & XDG Autostart'),
                        _buildAboutInfoRow(context, 'Sync Protocol', 'Ever Dialer RFCOMM Bluetooth Sync'),
                        _buildAboutInfoRow(context, 'Platform', 'Linux (x86_64, Wayland/X11)'),
                        _buildAboutInfoRow(context, 'Developer', 'Hari (svhp)'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Footer Info
                Center(
                  child: Text(
                    'PipeWire A2DP Audio Sink • BlueZ 5 • Fedora Linux • v1.0.0',
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

  Widget _buildAboutInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
