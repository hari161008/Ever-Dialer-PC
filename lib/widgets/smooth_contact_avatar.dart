import 'dart:convert';
import 'package:flutter/material.dart';

/// A circular contact avatar widget that provides:
/// 1. In-memory caching for decoded Base64 images to prevent recreation on rebuilds.
/// 2. Smooth and slow overlapping crossfade animation when the photo updates or loads.
/// 3. Zero-flicker stability when rebuilding without changes.
class SmoothContactAvatar extends StatelessWidget {
  final String? photoBase64;
  final double radius;
  final String? initials;
  final Widget? fallbackChild;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration duration;
  final Curve curve;
  final BoxBorder? border;

  // Global LRU / bounded cache for decoded MemoryImage instances.
  // Using the exact same MemoryImage prevents Flutter from disposing and
  // re-resolving image streams on every rebuild frame.
  static final Map<String, MemoryImage> _imageCache = {};
  static const int _maxCacheEntries = 500;

  const SmoothContactAvatar({
    super.key,
    this.photoBase64,
    this.radius = 22,
    this.initials,
    this.fallbackChild,
    this.backgroundColor,
    this.foregroundColor,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOut,
    this.border,
  });

  /// Look up or create a cached [MemoryImage] from base64 string.
  static MemoryImage? getImageProvider(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    final cached = _imageCache[b64];
    if (cached != null) return cached;

    try {
      final bytes = base64Decode(b64);
      final image = MemoryImage(bytes);
      if (_imageCache.length >= _maxCacheEntries) {
        _imageCache.remove(_imageCache.keys.first);
      }
      _imageCache[b64] = image;
      return image;
    } catch (_) {
      return null;
    }
  }

  /// Manually clear image cache if ever needed.
  static void clearCache() {
    _imageCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = backgroundColor ?? colorScheme.primaryContainer;
    final fg = foregroundColor ?? colorScheme.onPrimaryContainer;

    final imageProvider = getImageProvider(photoBase64);
    final size = radius * 2;

    Widget content;
    if (imageProvider != null) {
      content = KeyedSubtree(
        key: ValueKey<String>('img_${photoBase64.hashCode}'),
        child: SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: Image(
              image: imageProvider,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => _buildFallback(context, size, bg, fg),
            ),
          ),
        ),
      );
    } else {
      content = KeyedSubtree(
        key: ValueKey<String>('fallback_${initials ?? fallbackChild?.key ?? 'empty'}'),
        child: _buildFallback(context, size, bg, fg),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: content,
      ),
    );
  }

  Widget _buildFallback(BuildContext context, double size, Color bg, Color fg) {
    if (fallbackChild != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: fallbackChild),
      );
    }

    if (initials != null && initials!.trim().isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials!.trim(),
            style: TextStyle(
              fontSize: radius * 0.72,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          Icons.person,
          size: radius * 1.1,
          color: fg,
        ),
      ),
    );
  }
}
