import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class AudioStatusCard extends StatelessWidget {
  final BluetoothState state;
  final VoidCallback onUnmute;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onRepairAudio;
  final ValueChanged<String>? onSelectSink;

  const AudioStatusCard({
    super.key,
    required this.state,
    required this.onUnmute,
    required this.onVolumeChanged,
    this.onRepairAudio,
    this.onSelectSink,
  });

  String _cleanSinkName(String raw) {
    if (raw.toLowerCase().contains('speaker')) return 'PC Laptop Speaker';
    if (raw.toLowerCase().contains('headphone')) return 'Headphones';
    if (raw.toLowerCase().contains('hdmi 2')) return 'HDMI 2 Output';
    if (raw.toLowerCase().contains('hdmi 1')) return 'HDMI 1 Output';
    if (raw.toLowerCase().contains('hdmi 3')) return 'HDMI 3 Output';
    if (raw.toLowerCase().contains('hdmi')) return 'External HDMI Output';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMuted = state.speakerMuted;
    final hasProfileIssue =
        !state.phoneAudioProfileActive && state.connectedDevice != null;

    final currentSinkDesc = state.activeSinkDescription != null
        ? _cleanSinkName(state.activeSinkDescription!)
        : 'Default Speaker';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: (isMuted || hasProfileIssue)
              ? colorScheme.error.withValues(alpha: 0.4)
              : colorScheme.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: isMuted ? colorScheme.error : colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PC Audio Output',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        isMuted
                            ? 'Muted in PipeWire'
                            : (hasProfileIssue
                                ? 'Phone Stream Disabled in PipeWire'
                                : currentSinkDesc),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (isMuted || hasProfileIssue)
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Volume / Mute chip
                if (isMuted) ...[
                  FilledButton.tonalIcon(
                    onPressed: onUnmute,
                    icon: const Icon(Icons.volume_up, size: 16),
                    label: const Text('Unmute'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(state.speakerVolume * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Volume Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: state.speakerVolume.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                activeColor: isMuted ? colorScheme.error : colorScheme.primary,
                inactiveColor: colorScheme.surfaceContainerHighest,
                onChanged: onVolumeChanged,
              ),
            ),

            // Audio Sinks Switcher (If multiple audio outputs are available)
            if (state.availableSinks.length > 1 && onSelectSink != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.speaker_group_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Sink:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PopupMenuButton<String>(
                      initialValue: state.activeSinkName,
                      onSelected: onSelectSink,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                currentSinkDesc,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) {
                        return state.availableSinks.map((sink) {
                          final isSelected = sink.isDefault;
                          return PopupMenuItem<String>(
                            value: sink.name,
                            child: Row(
                              children: [
                                Icon(
                                  sink.description.toLowerCase().contains('speaker')
                                      ? Icons.laptop
                                      : Icons.tv,
                                  size: 18,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _cleanSinkName(sink.description),
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ],
              ),
            ],

            // Warning Banner if Profile is Off
            if (hasProfileIssue) ...[
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 20, color: colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Phone audio routing is currently OFF in PipeWire. Click "Fix PipeWire Audio" below to restore wireless streaming.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Laptop Muted Warning
            if (isMuted && !hasProfileIssue) ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 18, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your laptop speaker is currently muted. Click "Unmute" above so your phone sound can be heard.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Repair / Reset PipeWire Action Button
            if (onRepairAudio != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  onRepairAudio!();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Repairing PipeWire audio routing & unmuting speakers...'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.build_circle_outlined, size: 18),
                label: const Text('Fix PipeWire Audio Routing'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
