import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/sync_service.dart';
import '../widgets/rivo_components.dart';
import '../widgets/window_header_actions.dart';

Future<void> _launchUrl(String url) async {
  try {
    await Process.run('xdg-open', [url]);
  } catch (e) {
    debugPrint('Failed to open url: $url, error: $e');
  }
}

class AboutScreen extends StatelessWidget {
  final bool isPane;
  final SystemService? systemService;
  final PcSyncService? syncService;

  const AboutScreen({
    super.key,
    this.isPane = false,
    this.systemService,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Unified Hero Card ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: App icon on left, Title & Badges on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.dialpad,
                          size: 42,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ever Dialer PC',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Modern. Fast. Reliable.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Chips row
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 13,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'v1.0.0',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 13,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'GPL-3.0',
                                      style: TextStyle(
                                        fontSize: 12,
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

                // Quick stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        label: 'Installed Build',
                        value: 'v1.0.0',
                        icon: Icons.laptop_mac_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        label: 'License',
                        value: 'GNU GPL v3',
                        icon: Icons.code_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Developer & Source ────────────────────────
          const RivoSectionHeader(title: 'Developer & Source'),
          RivoExpressiveCard(
            child: RivoListItem(
              headline: 'Made By Hari :)',
              supporting: 'Lead Developer · Contact on Telegram',
              leadingIcon: Icons.person_outline,
              iconColor: const Color(0xFF2196F3),
              onClick: () => _launchUrl('https://t.me/Hari_svhp'),
            ),
          ),

          const SizedBox(height: 12),

          // ── Mount Fuji Donate Container ───────────────
          const MountFujiDonateCard(),

          const SizedBox(height: 12),

          RivoExpressiveCard(
            child: RivoListItem(
              headline: 'Source Code',
              supporting: 'GitHub Repository · Free & Open Source',
              leadingIcon: Icons.code_outlined,
              iconColor: const Color(0xFF4CAF50),
              trailing: const Icon(Icons.arrow_forward, size: 20),
              onClick: () => _launchUrl('https://github.com/harisvhp/Ever-Dialer'),
            ),
          ),

          const SizedBox(height: 16),

          // ── Community & Ecosystem ─────────────────────
          const RivoSectionHeader(title: 'Community & Ecosystem'),
          RivoExpressiveCard(
            child: Column(
              children: [
                RivoListItem(
                  headline: 'Telegram App Support Group',
                  supporting: 'Bug Reports | Feature Requests | Announcements | Support',
                  leadingIcon: Icons.groups_outlined,
                  iconColor: const Color(0xFF7C4DFF),
                  trailing: const Icon(Icons.arrow_forward, size: 20),
                  onClick: () => _launchUrl('https://t.me/everdialersupport'),
                ),
                const RivoDivider(),
                RivoListItem(
                  headline: 'App Recommending Channel in Telegram',
                  supporting: 'Discover | Explore | Cool Apps | Updates',
                  leadingIcon: Icons.star_outline,
                  iconColor: const Color(0xFF00BCD4),
                  trailing: const Icon(Icons.arrow_forward, size: 20),
                  onClick: () => _launchUrl('https://t.me/coolappstore'),
                ),
                const RivoDivider(),
                RivoListItem(
                  headline: 'My Other App (Everlasting Android Tweak)',
                  supporting: 'Tweaks | System Tools | Modify | Customize',
                  leadingIcon: Icons.build_outlined,
                  iconColor: const Color(0xFF009688),
                  trailing: const Icon(Icons.arrow_forward, size: 20),
                  onClick: () => _launchUrl('https://hariprabhu.com/Everlasting-Android-Tweak/'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Footer ────────────────────────────────────
          Center(
            child: Text(
              'Ever Dialer • Material You • Built with ♥',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (isPane) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: WindowDragArea(
          onStartDrag: () => systemService?.startWindowDrag(),
          onDoubleTap: () => systemService?.toggleMaximizeWindow(),
          child: const SizedBox.expand(),
        ),
        title: const Text('About Ever Dialer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          WindowHeaderActions(
            syncService: syncService,
            systemService: systemService,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Mount Fuji Donate Card matching mobile About screen
class MountFujiDonateCard extends StatefulWidget {
  const MountFujiDonateCard({super.key});

  @override
  State<MountFujiDonateCard> createState() => _MountFujiDonateCardState();
}

class _MountFujiDonateCardState extends State<MountFujiDonateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Fuji landscape animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MountFujiPainter(
                    animationProgress: _animController.value,
                    primaryColor: colorScheme.primary,
                    secondaryColor: colorScheme.secondary,
                    tertiaryColor: colorScheme.tertiary,
                    surfaceColor: colorScheme.surfaceContainerHigh,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // Foreground Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "SUPPORT DEVELOPMENT" Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 13, color: colorScheme.error),
                      const SizedBox(width: 6),
                      Text(
                        'SUPPORT DEVELOPMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onErrorContainer,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Donate',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'Support this open-source project and future updates. Every contribution matters!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Donation action buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _launchUrl('https://hariprabhu.com/#donate'),
                      icon: const Icon(Icons.favorite, size: 16),
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Contribute', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 15),
                        ],
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),

                    // Buy Me a Coffee Button
                    Material(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => _launchUrl('https://buymeacoffee.com/hariprabhu'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFDD00), Color(0xFFFFC000), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.coffee, size: 16, color: Color(0xFF231600)),
                              SizedBox(width: 6),
                              Text(
                                'Buy Me A Coffee',
                                style: TextStyle(
                                  color: Color(0xFF231600),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14, color: Color(0xFF231600)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // GitHub Sponsors Button
                    Material(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => _launchUrl('https://github.com/sponsors/hari161008'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEA4AAA), Color(0xFFDB2777), Color(0xFFBE185D)],
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'GitHub Sponsor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MountFujiPainter extends CustomPainter {
  final double animationProgress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color surfaceColor;
  final bool isDark;

  _MountFujiPainter({
    required this.animationProgress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.surfaceColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Atmosphere Radial Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.22 : 0.14),
          tertiaryColor.withValues(alpha: isDark ? 0.10 : 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.82, h * 0.24), radius: h * 0.75));
    canvas.drawCircle(Offset(w * 0.82, h * 0.24), h * 0.75, glowPaint);

    // 2. Stars
    final starTwinkle = 0.5 + 0.5 * math.sin(animationProgress * 2 * math.pi);
    _drawStar(canvas, Offset(w * 0.58, h * 0.12), 7, starTwinkle * 0.75);
    _drawStar(canvas, Offset(w * 0.74, h * 0.08), 8, (1.0 - starTwinkle) * 0.85);
    _drawStar(canvas, Offset(w * 0.90, h * 0.14), 6, starTwinkle * 0.65);

    // 3. Mount Fuji Mountain Ridge (Background)
    final ridgePath = Path()
      ..moveTo(w * 0.42, h + 10)
      ..cubicTo(w * 0.50, h * 0.78, w * 0.56, h * 0.55, w * 0.64, h * 0.42)
      ..cubicTo(w * 0.70, h * 0.50, w * 0.76, h * 0.60, w * 0.88, h * 0.52)
      ..lineTo(w * 1.10, h + 10)
      ..close();
    final ridgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tertiaryColor.withValues(alpha: isDark ? 0.24 : 0.15),
          surfaceColor.withValues(alpha: isDark ? 0.45 : 0.30),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.42, w, h * 0.58));
    canvas.drawPath(ridgePath, ridgePaint);

    // 4. Majestic Mount Fuji (Sunlit left slope & Shaded right slope)
    final peakTop = h * 0.18;
    final peakLeft = w * 0.77;
    final peakMid = w * 0.81;
    final peakRight = w * 0.86;
    final baseLeft = w * 0.46;
    final baseMid = w * 0.78;
    final baseRight = w * 1.15;
    final baseBottom = h + 15;

    // Left Facet (Sunlit)
    final leftSlope = Path()
      ..moveTo(baseLeft, baseBottom)
      ..cubicTo(w * 0.56, h * 0.82, w * 0.68, h * 0.48, peakLeft, peakTop)
      ..lineTo(peakMid, peakTop)
      ..cubicTo(w * 0.80, h * 0.45, w * 0.79, h * 0.75, baseMid, baseBottom)
      ..close();
    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.38 : 0.25),
          surfaceColor.withValues(alpha: isDark ? 0.58 : 0.42),
        ],
      ).createShader(Rect.fromLTWH(0, peakTop, w, baseBottom - peakTop));
    canvas.drawPath(leftSlope, leftPaint);

    // Right Facet (Shaded)
    final rightSlope = Path()
      ..moveTo(baseMid, baseBottom)
      ..cubicTo(w * 0.79, h * 0.75, w * 0.80, h * 0.45, peakMid, peakTop)
      ..lineTo(peakRight, peakTop + h * 0.015)
      ..cubicTo(w * 0.94, h * 0.50, w * 1.04, h * 0.80, baseRight, baseBottom)
      ..close();
    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          secondaryColor.withValues(alpha: isDark ? 0.48 : 0.34),
          surfaceColor.withValues(alpha: isDark ? 0.72 : 0.54),
        ],
      ).createShader(Rect.fromLTWH(0, peakTop, w, baseBottom - peakTop));
    canvas.drawPath(rightSlope, rightPaint);

    // 5. Snow Cap (Left bright, Right slightly shaded)
    final leftSnow = Path()
      ..moveTo(peakLeft, peakTop)
      ..lineTo(peakMid, peakTop)
      ..lineTo(peakMid, peakTop + h * 0.17)
      ..lineTo(w * 0.79, peakTop + h * 0.14)
      ..lineTo(w * 0.77, peakTop + h * 0.19)
      ..lineTo(w * 0.75, peakTop + h * 0.13)
      ..lineTo(w * 0.73, peakTop + h * 0.18)
      ..close();
    canvas.drawPath(
      leftSnow,
      Paint()..color = Colors.white.withValues(alpha: isDark ? 0.80 : 0.95),
    );

    final rightSnow = Path()
      ..moveTo(peakMid, peakTop)
      ..lineTo(peakRight, peakTop + h * 0.015)
      ..lineTo(w * 0.90, peakTop + h * 0.18)
      ..lineTo(w * 0.87, peakTop + h * 0.13)
      ..lineTo(w * 0.85, peakTop + h * 0.19)
      ..lineTo(w * 0.83, peakTop + h * 0.14)
      ..lineTo(peakMid, peakTop + h * 0.17)
      ..close();
    canvas.drawPath(
      rightSnow,
      Paint()..color = (isDark ? const Color(0xFFD6E4F0) : const Color(0xFFEBF2F8)).withValues(alpha: isDark ? 0.65 : 0.80),
    );

    // 6. Floating Cherry Blossom Petals
    final petalPaint = Paint()..color = const Color(0xFFFFB7C5).withValues(alpha: 0.6);
    for (int i = 0; i < 6; i++) {
      final pT = (animationProgress + i * 0.16) % 1.0;
      final px = w * (0.95 - pT * 0.5) + math.sin(pT * 6.28 + i) * 18;
      final py = h * 0.08 + pT * (h * 0.85);
      canvas.drawCircle(Offset(px, py), 3.0, petalPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, double alpha) {
    if (alpha <= 0) return;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _MountFujiPainter oldDelegate) => true;
}
