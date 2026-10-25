import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/system_service.dart';

class VolumePopupDialog extends StatefulWidget {
  final PcSyncService? syncService;
  final SystemService? systemService;

  const VolumePopupDialog({
    super.key,
    this.syncService,
    this.systemService,
  });

  static Future<void> show(
    BuildContext context, {
    PcSyncService? syncService,
    SystemService? systemService,
  }) {
    systemService?.refreshPcVolume();
    syncService?.requestTelemetryNow();

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          elevation: 6,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: VolumePopupDialog(
              syncService: syncService,
              systemService: systemService,
            ),
          ),
        );
      },
    );
  }

  @override
  State<VolumePopupDialog> createState() => _VolumePopupDialogState();
}

class _VolumePopupDialogState extends State<VolumePopupDialog> {
  int _selectedTab = 0; // 0 = PC, 1 = Mobile

  // Local optimistic values for smooth sliding
  int? _localPcVol;
  final Map<String, int> _localMobileVol = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncService = widget.syncService;
    final systemService = widget.systemService;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Volume Control',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two Options Segmented Switch: PC volume vs Mobile volume
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 0,
                label: Text('PC volume'),
                icon: Icon(Icons.laptop_rounded, size: 18),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Mobile volume'),
                icon: Icon(Icons.smartphone_rounded, size: 18),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedTab = newSelection.first;
              });
              if (_selectedTab == 0) {
                widget.systemService?.refreshPcVolume();
              } else {
                widget.syncService?.requestTelemetryNow();
              }
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 18),

          // Content based on tab
          if (_selectedTab == 0)
            _buildPcVolumeSection(theme, colorScheme, systemService)
          else
            _buildMobileVolumeSection(theme, colorScheme, syncService),
        ],
      ),
    );
  }

  Widget _buildPcVolumeSection(
    ThemeData theme,
    ColorScheme colorScheme,
    SystemService? systemService,
  ) {
    if (systemService == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'PC Audio service unavailable',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
      );
    }

    return ListenableBuilder(
      listenable: systemService,
      builder: (context, _) {
        final pcVol = _localPcVol ?? systemService.pcVolume;
        final isMuted = systemService.pcMuted;

        final IconData volIcon;
        if (isMuted || pcVol == 0) {
          volIcon = Icons.volume_off_rounded;
        } else if (pcVol < 40) {
          volIcon = Icons.volume_down_rounded;
        } else {
          volIcon = Icons.volume_up_rounded;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PC Master Volume',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isMuted ? 'Muted' : '$pcVol%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isMuted ? colorScheme.error : colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      volIcon,
                      color: isMuted ? colorScheme.error : colorScheme.primary,
                    ),
                    tooltip: isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      systemService.togglePcMute();
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: pcVol.toDouble().clamp(0.0, 100.0),
                      min: 0,
                      max: 100,
                      onChanged: (val) {
                        setState(() {
                          _localPcVol = val.round();
                        });
                        systemService.setPcVolume(val.round());
                      },
                      onChangeEnd: (val) {
                        setState(() {
                          _localPcVol = null;
                        });
                        systemService.setPcVolume(val.round());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileVolumeSection(
    ThemeData theme,
    ColorScheme colorScheme,
    PcSyncService? syncService,
  ) {
    if (syncService == null || !syncService.isConnected) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.bluetooth_searching, size: 36, color: colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              'Phone Not Connected',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect your phone over Bluetooth in PC Connect to adjust mobile volumes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        final vol = syncService.telemetry.volume;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVolumeSliderRow(
              title: 'Ring',
              icon: Icons.notifications_active_rounded,
              streamKey: 'ring',
              stream: vol.ring,
              syncService: syncService,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const Divider(height: 12),
            _buildVolumeSliderRow(
              title: 'Notification',
              icon: Icons.notifications_rounded,
              streamKey: 'notification',
              stream: vol.notification,
              syncService: syncService,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const Divider(height: 12),
            _buildVolumeSliderRow(
              title: 'System Call volume',
              icon: Icons.phone_in_talk_rounded,
              streamKey: 'call',
              stream: vol.call,
              syncService: syncService,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const Divider(height: 12),
            _buildVolumeSliderRow(
              title: 'Alarm',
              icon: Icons.alarm_rounded,
              streamKey: 'alarm',
              stream: vol.alarm,
              syncService: syncService,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const Divider(height: 12),
            _buildVolumeSliderRow(
              title: 'Media',
              icon: Icons.music_note_rounded,
              streamKey: 'media',
              stream: vol.media,
              syncService: syncService,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ],
        );
      },
    );
  }

  Widget _buildVolumeSliderRow({
    required String title,
    required IconData icon,
    required String streamKey,
    required SyncedVolumeStream stream,
    required PcSyncService syncService,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final maxVol = stream.max > 0 ? stream.max : 15;
    final currentVol = (_localMobileVol[streamKey] ?? stream.current).clamp(0, maxVol);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Tooltip(
            message: title,
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Slider(
              value: currentVol.toDouble(),
              min: 0,
              max: maxVol.toDouble(),
              divisions: maxVol > 0 ? maxVol : null,
              onChanged: (val) {
                setState(() {
                  _localMobileVol[streamKey] = val.round();
                });
                syncService.setPhoneVolume(streamKey, val.round());
              },
              onChangeEnd: (val) {
                setState(() {
                  _localMobileVol.remove(streamKey);
                });
                syncService.setPhoneVolume(streamKey, val.round());
              },
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$currentVol',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
