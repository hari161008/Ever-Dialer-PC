import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/system_service.dart';

class WindowResizeFrame extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final double cornerSize;

  const WindowResizeFrame({
    super.key,
    required this.child,
    this.borderWidth = 6.0,
    this.cornerSize = 12.0,
  });

  Widget _buildResizeZone({
    required String edge,
    required MouseCursor cursor,
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons == kPrimaryMouseButton) {
              SystemService.startResize(edge);
            }
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Edges
        _buildResizeZone(
          edge: 'top',
          cursor: SystemMouseCursors.resizeUpDown,
          top: 0,
          left: cornerSize,
          right: cornerSize,
          height: borderWidth,
        ),
        _buildResizeZone(
          edge: 'bottom',
          cursor: SystemMouseCursors.resizeUpDown,
          bottom: 0,
          left: cornerSize,
          right: cornerSize,
          height: borderWidth,
        ),
        _buildResizeZone(
          edge: 'left',
          cursor: SystemMouseCursors.resizeLeftRight,
          left: 0,
          top: cornerSize,
          bottom: cornerSize,
          width: borderWidth,
        ),
        _buildResizeZone(
          edge: 'right',
          cursor: SystemMouseCursors.resizeLeftRight,
          right: 0,
          top: cornerSize,
          bottom: cornerSize,
          width: borderWidth,
        ),
        // Corners
        _buildResizeZone(
          edge: 'topLeft',
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          left: 0,
          top: 0,
          width: cornerSize,
          height: cornerSize,
        ),
        _buildResizeZone(
          edge: 'topRight',
          cursor: SystemMouseCursors.resizeUpRightDownLeft,
          right: 0,
          top: 0,
          width: cornerSize,
          height: cornerSize,
        ),
        _buildResizeZone(
          edge: 'bottomLeft',
          cursor: SystemMouseCursors.resizeUpRightDownLeft,
          left: 0,
          bottom: 0,
          width: cornerSize,
          height: cornerSize,
        ),
        _buildResizeZone(
          edge: 'bottomRight',
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          right: 0,
          bottom: 0,
          width: cornerSize,
          height: cornerSize,
        ),
      ],
    );
  }
}
