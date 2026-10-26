import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/system_service.dart';
import 'volume_popup.dart';

class _BottomUpClipper extends CustomClipper<Rect> {
  final double fraction;

  const _BottomUpClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    final top = size.height * (1.0 - fraction.clamp(0.0, 1.0));
    return Rect.fromLTRB(0, top, size.width, size.height);
  }

  @override
  bool shouldReclip(_BottomUpClipper oldClipper) => oldClipper.fraction != fraction;
}

class _LeftToRightClipper extends CustomClipper<Rect> {
  final double fraction;

  const _LeftToRightClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    final right = size.width * fraction.clamp(0.0, 1.0);
    return Rect.fromLTRB(0, 0, right, size.height);
  }

  @override
  bool shouldReclip(_LeftToRightClipper oldClipper) => oldClipper.fraction != fraction;
}

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

  Widget _buildWifiWidget(BuildContext context, int level, bool isConnected) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isConnected || level < 0) {
      return Icon(
        Icons.wifi_off_rounded,
        size: 19,
        color: colorScheme.outline.withValues(alpha: 0.6),
      );
    }

    final double fraction;
    switch (level) {
      case 0:
        fraction = 0.0;
        break;
      case 1:
        fraction = 0.38;
        break;
      case 2:
        fraction = 0.62;
        break;
      case 3:
        fraction = 0.82;
        break;
      default:
        fraction = 1.0;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.wifi_rounded,
          size: 19,
          color: colorScheme.outline.withValues(alpha: 0.25),
        ),
        if (fraction > 0.0)
          ClipRect(
            clipper: _BottomUpClipper(fraction),
            child: Icon(
              Icons.wifi_rounded,
              size: 19,
              color: colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildCellularWidget(BuildContext context, int level, bool isConnected) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isConnected || level < 0) {
      return Icon(
        Icons.signal_cellular_off_rounded,
        size: 19,
        color: colorScheme.outline.withValues(alpha: 0.6),
      );
    }

    final double fraction;
    switch (level) {
      case 0:
        fraction = 0.0;
        break;
      case 1:
        fraction = 0.32;
        break;
      case 2:
        fraction = 0.58;
        break;
      case 3:
        fraction = 0.80;
        break;
      default:
        fraction = 1.0;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.signal_cellular_4_bar_rounded,
          size: 19,
          color: colorScheme.outline.withValues(alpha: 0.25),
        ),
        if (fraction > 0.0)
          ClipRect(
            clipper: _LeftToRightClipper(fraction),
            child: Icon(
              Icons.signal_cellular_4_bar_rounded,
              size: 19,
              color: colorScheme.primary,
            ),
          ),
      ],
    );
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

    final listenables = <Listenable>[
      ?syncService,
      ?systemService,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...?leadingActions,

        // Telemetry & Bluetooth Status Indicators
        if (listenables.isNotEmpty)
          ListenableBuilder(
            listenable: Listenable.merge(listenables),
            builder: (context, _) {
              final isConnected = syncService?.isConnected ?? false;
              final telem = syncService?.telemetry ?? const SyncedTelemetry();
              final deviceName = syncService?.connectedDeviceName ?? 'Phone';

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
                  syncService?.requestSyncNow();
                  syncService?.requestTelemetryNow();
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

              // 2. Volume Controls Button (After Bluetooth)
              final isPcMuted = systemService?.pcMuted == true;
              final pcVol = systemService?.pcVolume ?? 50;
              final IconData volIcon;
              if (isPcMuted || pcVol == 0) {
                volIcon = Icons.volume_off_rounded;
              } else if (pcVol < 40) {
                volIcon = Icons.volume_down_rounded;
              } else {
                volIcon = Icons.volume_up_rounded;
              }

              final volumeWidget = IconButton(
                icon: Icon(
                  volIcon,
                  color: isConnected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: 'Volume Controls (PC & Mobile)',
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: () {
                  VolumePopupDialog.show(
                    context,
                    syncService: syncService,
                    systemService: systemService,
                  );
                },
              );

              final screenWidth = MediaQuery.sizeOf(context).width;
              final isNarrow = screenWidth < 580;
              final isVeryNarrow = screenWidth < 460;

              // 3. Phone Wi-Fi Strength (Consistent Icon, No Gaps)
              final bool showWifi = !isVeryNarrow || (isConnected && telem.isWifiConnected);
              final wifiTooltip = isConnected
                  ? (telem.isWifiConnected
                      ? 'Phone Wi-Fi: Connected (${telem.wifiLevel >= 0 ? "${telem.wifiLevel}/4" : "Active"})'
                      : 'Phone Wi-Fi: Disconnected')
                  : 'Phone Wi-Fi: Disconnected';
              final Widget? wifiWidget = showWifi
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Tooltip(
                        message: wifiTooltip,
                        child: _buildWifiWidget(context, telem.wifiLevel, isConnected && telem.isWifiConnected),
                      ),
                    )
                  : null;

              // 4. Hotspot Icon (Beside Wi-Fi, only visible when on)
              final Widget? hotspotWidget;
              if (isConnected && telem.isHotspotOn) {
                hotspotWidget = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Tooltip(
                    message: 'Mobile Hotspot: Active',
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              } else {
                hotspotWidget = null;
              }

              // 5. Phone Cellular Signal Strength (Consistent Triangle, No Line Gaps)
              final bool showCell = !isVeryNarrow || isConnected;
              final cellTooltip = isConnected
                  ? (telem.cellularLevel >= 0
                      ? 'Phone Signal: ${telem.cellularLevel}/4'
                      : 'Phone Signal: No Service')
                  : 'Phone Signal: Disconnected';
              final Widget? cellWidget = showCell
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Tooltip(
                        message: cellTooltip,
                        child: _buildCellularWidget(context, telem.cellularLevel, isConnected),
                      ),
                    )
                  : null;

              // 6. Network Data Type Badge (4G / 5G / LTE beside SIM icon)
              final Widget? dataBadge;
              if (!isNarrow && isConnected && telem.dataNetworkType.isNotEmpty) {
                dataBadge = Padding(
                  padding: const EdgeInsets.only(right: 3.0),
                  child: Tooltip(
                    message: 'Data Network: ${telem.dataNetworkType}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        telem.dataNetworkType,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                dataBadge = null;
              }

              // 7. Phone Battery (Icon and Percentage)
              final batteryIconData = _getBatteryIcon(telem.batteryLevel, telem.isBatteryCharging);
              final batteryText = isConnected && telem.batteryLevel >= 0
                  ? '${telem.batteryLevel}%'
                  : '--%';
              final batteryTooltip = isConnected && telem.batteryLevel >= 0
                  ? 'Phone Battery: ${telem.batteryLevel}%${telem.isBatteryCharging ? " (Charging)" : ""}'
                  : 'Phone Battery: Disconnected';
              final batteryWidget = Padding(
                padding: EdgeInsets.only(
                  left: 2.0,
                  right: isNarrow ? 4.0 : 8.0,
                ),
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
                      if (!isNarrow) ...[
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
                    ],
                  ),
                ),
              );

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bluetoothWidget,
                  volumeWidget,
                  ?wifiWidget,
                  ?hotspotWidget,
                  ?cellWidget,
                  ?dataBadge,
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

class WindowDragArea extends StatefulWidget {
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
  State<WindowDragArea> createState() => _WindowDragAreaState();
}

class _WindowDragAreaState extends State<WindowDragArea> {
  Offset? _downPos;
  bool _hasStartedDrag = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: widget.onDoubleTap,
      onPanStart: (_) {
        _hasStartedDrag = true;
        widget.onStartDrag?.call();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == 1) {
            _downPos = event.position;
            _hasStartedDrag = false;
          }
        },
        onPointerMove: (event) {
          if (event.buttons == 1 && !_hasStartedDrag && _downPos != null) {
            final distance = (event.position - _downPos!).distance;
            if (distance > 3.0) {
              _hasStartedDrag = true;
              widget.onStartDrag?.call();
            }
          }
        },
        onPointerUp: (_) {
          _downPos = null;
          _hasStartedDrag = false;
        },
        onPointerCancel: (_) {
          _downPos = null;
          _hasStartedDrag = false;
        },
        child: widget.child,
      ),
    );
  }
}


