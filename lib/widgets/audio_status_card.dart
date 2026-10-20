import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class AudioStatusCard extends StatelessWidget {
  final BluetoothState state;
  final VoidCallback onUnmute;
  final ValueChanged<double> onVolumeChanged;

  const AudioStatusCard({
    super.key,
    required this.state,
    required this.onUnmute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMuted = state.speakerMuted;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isMuted
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
                        isMuted ? 'Muted in PipeWire' : 'Active Output',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isMuted
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            if (isMuted) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: colorScheme.error),
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
          ],
        ),
      ),
    );
  }
}
