import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bluetooth_service.dart';
import '../services/sync_service.dart';

class BluetoothContainer extends StatelessWidget {
  final BluetoothState state;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onDisconnect;
  final PcSyncService? syncService;

  const BluetoothContainer({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onDisconnect,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = state.speakerModeEnabled || (syncService?.pcSyncEnabled ?? false);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final padding = isNarrow ? 16.0 : 20.0;

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bluetooth Icon in Material You Squircle
                    Container(
                      width: isNarrow ? 44 : 50,
                      height: isNarrow ? 44 : 50,
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(isNarrow ? 14 : 16),
                      ),
                      child: Center(
                        child: Icon(
                          isEnabled ? Icons.bluetooth_connected : Icons.bluetooth,
                          size: isNarrow ? 24 : 26,
                          color: isEnabled
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.outline,
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 12 : 14),

                    // Title and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth Connection & Sync',
                            style: (isNarrow
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEnabled
                                ? 'Syncing with Ever Dialer Mobile and streaming phone audio'
                                : 'Sync phone data and use this PC as a wireless media speaker',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: isNarrow ? 12 : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Material 3 Switch Toggle
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

                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.6,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 14),

                // Container Body depending on toggle state
                if (isEnabled) ...[
                  _buildActiveState(context, isNarrow: isNarrow),
                ] else ...[
                  _buildInactiveState(context, isNarrow: isNarrow),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveState(BuildContext context, {required bool isNarrow}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final device = state.connectedDevice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status chips wrap
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (device != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Flexible(
                      child: Text(
                        'Connected: ${device.name}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Flexible(
                      child: Text(
                        'Discoverable — Ready for Phone',
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            if (syncService != null && syncService!.isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync,
                      size: 14,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sync Active',
                      style: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
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
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      state.alias,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 12, color: colorScheme.outline),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (device != null) ...[
          // Connected Phone Details Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.smartphone,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MAC: ${device.mac}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              state.phoneAudioProfileActive
                                  ? 'Streaming audio to PC speakers via PipeWire A2DP'
                                  : 'Audio stream profile inactive (Disabled in PipeWire)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: state.phoneAudioProfileActive
                                    ? colorScheme.primary
                                    : colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => onDisconnect(device.mac),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  )
                : Row(
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
                                Expanded(
                                  child: Text(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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
            padding: EdgeInsets.all(isNarrow ? 12 : 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 19,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'How to stream audio from your phone:',
                        style: (isNarrow
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.titleSmall)
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
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
                      'Open Ever Dialer on your phone to sync data & stream audio to PC speakers!',
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
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInactiveState(BuildContext context, {required bool isNarrow}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Bluetooth & Sync Disabled',
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Turn on the toggle above to connect with Ever Dialer Mobile for data sync and wireless audio streaming.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: isNarrow ? 12.5 : null,
            ),
          ),
        ],
      ),
    );
  }
}
