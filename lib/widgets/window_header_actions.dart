import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/system_service.dart';

class WindowHeaderActions extends StatelessWidget {
  final PcSyncService? syncService;
  final SystemService? systemService;
  final List<Widget>? leadingActions;

  const WindowHeaderActions({
    super.key,
    this.syncService,
    this.systemService,
    this.leadingActions,
  });

  IconData _getWifiIcon(int level, bool isConnected) {
    if (!isConnected || level < 0) {
      return Icons.wifi_off_rounded;
    }
    switch (level) {
      case 0:
        return Icons.signal_wifi_0_bar_rounded;
      case 1:
        return Icons.network_wifi_1_bar_rounded;
      case 2:
        return Icons.network_wifi_2_bar_rounded;
      case 3:
        return Icons.network_wifi_3_bar_rounded;
      default:
        return Icons.wifi_rounded;
    }
  }

  IconData _getCellularIcon(int level) {
    if (level < 0) {
      return Icons.signal_cellular_off_rounded;
    }
    switch (level) {
      case 0:
        return Icons.signal_cellular_0_bar_rounded;
      case 1:
        return Icons.signal_cellular_alt_1_bar_rounded;
      case 2:
        return Icons.signal_cellular_alt_2_bar_rounded;
      case 3:
        return Icons.signal_cellular_alt_rounded;
      default:
        return Icons.signal_cellular_4_bar_rounded;
    }
  }

  IconData _getBatteryIcon(int level, bool isCharging) {
    if (isCharging) {
      return Icons.battery_charging_full_rounded;
    }
    if (level < 0) {
      return Icons.battery_unknown_rounded;
    }
    if (level <= 15) {
      return Icons.battery_alert_rounded;
    } else if (level <= 30) {
      return Icons.battery_2_bar_rounded;
    } else if (level <= 55) {
      return Icons.battery_4_bar_rounded;
    } else if (level <= 75) {
      return Icons.battery_5_bar_rounded;
    } else if (level <= 90) {
      return Icons.battery_6_bar_rounded;
    } else {
      return Icons.battery_full_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...?leadingActions,

        // Telemetry & Bluetooth Status Indicators
        if (syncService != null)
          ListenableBuilder(
            listenable: syncService!,
            builder: (context, _) {
              final isConnected = syncService!.isConnected;
              final telem = syncService!.telemetry;
              final deviceName = syncService!.connectedDeviceName ?? 'Phone';

              // 1. Bluetooth Connected/Disconnected Status Icon
              final bluetoothWidget = IconButton(
                icon: Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_searching,
                  color: isConnected ? colorScheme.primary : colorScheme.outline,
                  size: 20,
                ),
                tooltip: isConnected
                    ? 'Synced with $deviceName. Click to refresh.'
                    : 'Searching for Ever Dialer Mobile... Click to refresh.',
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: () {
                  syncService!.requestSyncNow();
                  syncService!.requestTelemetryNow();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isConnected
                            ? 'Requesting sync from $deviceName...'
                            : 'Listening for Bluetooth connection from Ever Dialer Mobile...',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );

              // 2. Phone Wi-Fi Strength (Icon Only)
              final wifiIconData = _getWifiIcon(telem.wifiLevel, telem.isWifiConnected);
              final isWifiActive = isConnected && telem.isWifiConnected;
              final wifiTooltip = isConnected
                  ? (telem.isWifiConnected
                      ? 'Phone Wi-Fi: Connected (${telem.wifiLevel >= 0 ? "${telem.wifiLevel}/4" : "Active"})'
                      : 'Phone Wi-Fi: Disconnected')
                  : 'Phone Wi-Fi: Disconnected';
              final wifiWidget = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Tooltip(
                  message: wifiTooltip,
                  child: Icon(
                    wifiIconData,
                    size: 19,
                    color: isWifiActive
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.6),
                  ),
                ),
              );

              // 3. Phone Cellular Signal Strength (Icon Only)
              final cellIconData = _getCellularIcon(telem.cellularLevel);
              final isCellActive = isConnected && telem.cellularLevel >= 0;
              final cellTooltip = isConnected
                  ? (telem.cellularLevel >= 0
                      ? 'Phone Signal: ${telem.cellularLevel}/4'
                      : 'Phone Signal: No Service')
                  : 'Phone Signal: Disconnected';
              final cellWidget = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Tooltip(
                  message: cellTooltip,
                  child: Icon(
                    cellIconData,
                    size: 19,
                    color: isCellActive
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.6),
                  ),
                ),
              );

              // 4. Phone Battery (Icon and Percentage)
              final batteryIconData = _getBatteryIcon(telem.batteryLevel, telem.isBatteryCharging);
              final batteryText = isConnected && telem.batteryLevel >= 0
                  ? '${telem.batteryLevel}%'
                  : '--%';
              final batteryTooltip = isConnected && telem.batteryLevel >= 0
                  ? 'Phone Battery: ${telem.batteryLevel}%${telem.isBatteryCharging ? " (Charging)" : ""}'
                  : 'Phone Battery: Disconnected';
              final batteryWidget = Padding(
                padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                child: Tooltip(
                  message: batteryTooltip,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        batteryIconData,
                        size: 19,
                        color: isConnected && telem.batteryLevel >= 0
                            ? (telem.batteryLevel <= 15
                                ? colorScheme.error
                                : colorScheme.primary)
                            : colorScheme.outline.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        batteryText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isConnected && telem.batteryLevel >= 0
                              ? colorScheme.onSurface
                              : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bluetoothWidget,
                  wifiWidget,
                  cellWidget,
                  batteryWidget,
                ],
              );
            },
          ),

        // Subtle divider separating status indicators from window controls
        Container(
          height: 18,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),

        // Window Control Buttons (Minimize, Maximize/Restore, Close)
        _WindowButton(
          icon: Icons.remove,
          tooltip: 'Minimize',
          onPressed: () => systemService?.minimizeWindow(),
        ),
        _WindowButton(
          icon: systemService?.isMaximized == true
              ? Icons.filter_none
              : Icons.crop_square,
          iconSize: 15,
          tooltip: systemService?.isMaximized == true ? 'Restore' : 'Maximize',
          onPressed: () => systemService?.toggleMaximizeWindow(),
        ),
        _WindowButton(
          icon: Icons.close,
          tooltip: 'Close',
          isClose: true,
          onPressed: () => systemService?.closeWindow(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    this.iconSize = 18,
    required this.tooltip,
    this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bg;
    Color fg;

    if (widget.isClose) {
      bg = _isHovered ? colorScheme.error : Colors.transparent;
      fg = _isHovered ? colorScheme.onError : colorScheme.onSurfaceVariant;
    } else {
      bg = _isHovered ? colorScheme.surfaceContainerHighest : Colors.transparent;
      fg = colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class WindowDragArea extends StatelessWidget {
  final Widget child;
  final VoidCallback? onStartDrag;
  final VoidCallback? onDoubleTap;

  const WindowDragArea({
    super.key,
    required this.child,
    this.onStartDrag,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTap,
      onPanStart: (_) => onStartDrag?.call(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == 1) {
            onStartDrag?.call();
          }
        },
        child: child,
      ),
    );
  }
}
