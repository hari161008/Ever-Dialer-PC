import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bluetooth_service.dart';

class BluetoothContainer extends StatelessWidget {
  final BluetoothState state;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onDisconnect;

  const BluetoothContainer({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = state.speakerModeEnabled;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            Row(
              children: [
                // Bluetooth Icon in Material You Squircle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      isEnabled ? Icons.bluetooth_connected : Icons.bluetooth,
                      size: 28,
                      color: isEnabled
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth Connection',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Use this PC as a wireless media speaker for your phone',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Material 3 Switch Toggle (Default: OFF)
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Icon(
                        Icons.check,
                        color: colorScheme.onPrimary,
                        size: 18,
                      );
                    }
                    return null;
                  }),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 14),

            // Container Body depending on toggle state
            if (isEnabled) ...[
              _buildActiveState(context),
            ] else ...[
              _buildInactiveState(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final device = state.connectedDevice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status chips row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (device != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected: ${device.name}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discoverable — Ready for Phone',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Broadcast Name Pill
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                Clipboard.setData(ClipboardData(text: state.alias));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "${state.alias}" to clipboard'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 15, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      state.alias,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 13, color: colorScheme.outline),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (device != null) ...[
          // Connected Phone Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.smartphone,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MAC: ${device.mac}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            state.phoneAudioProfileActive
                                ? Icons.graphic_eq
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: state.phoneAudioProfileActive
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.phoneAudioProfileActive
                                ? 'Streaming audio to PC speakers via PipeWire A2DP'
                                : 'Audio stream profile inactive (Disabled in PipeWire)',
                            style: TextStyle(
                              fontSize: 12,
                              color: state.phoneAudioProfileActive
                                  ? colorScheme.primary
                                  : colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onDisconnect(device.mac),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Step by step pairing guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How to stream audio from your phone:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGuideStep(
                  context,
                  step: '1',
                  text: 'On your phone, open Settings → Bluetooth.',
                ),
                const SizedBox(height: 6),
                _buildGuideStep(
                  context,
                  step: '2',
                  text: 'Tap on "${state.alias}" in available devices to pair.',
                ),
                const SizedBox(height: 6),
                _buildGuideStep(
                  context,
                  step: '3',
                  text:
                      'Play YouTube, Spotify, podcasts, or videos on your phone — audio will stream right here!',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGuideStep(
    BuildContext context, {
    required String step,
    required String text,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInactiveState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Media Speaker Mode Disabled',
                style: TextStyle(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Turn on the toggle above to make this PC discoverable and accept wireless audio streaming from your mobile device.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
