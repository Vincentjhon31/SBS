import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../theme/background_style_controller.dart';

/// The shared page backdrop — three user-selectable looks (Settings →
/// Appearance): a "liquid glass" glow, organic floating "blob" shapes, or
/// a flat solid surface for lower-end devices/browsers. Used everywhere a
/// screen wants ambient depth instead of a flat background: the citizen
/// app shell, login/splash, every pushed screen, and (when a staffer picks
/// glossy/blob over the default solid) the staff web dashboard canvas.
///
/// Either decorated style is baked into a single static, cached layer
/// (RepaintBoundary) rather than a live BackdropFilter over scrolling
/// content, so it stays cheap even when left on.
class GlossyBackground extends ConsumerWidget {
  const GlossyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = ref.watch(backgroundStyleProvider);

    if (style == BackgroundStyle.solid) {
      // Cheapest possible: a flat scaffold-matching surface, no blur.
      // Must fill the whole area, not shrink to [child] — screens push with
      // a transparent Scaffold, so a shrink-wrapped solid layer let the
      // uncovered region fall through to black (only on pages without a
      // bottom nav, where nothing else painted behind it). A full-bleed
      // stack guarantees the surface always covers the viewport.
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: dark ? AppConstants.darkSurface : AppConstants.lightSurface,
          ),
          child,
        ],
      );
    }

    return Stack(
      // Loose fit (the default) would give the non-positioned [child] its
      // own natural size instead of filling the screen, silently breaking
      // any Expanded/Flexible inside it (e.g. the sidebar shell's Row).
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [
                              Color(0xFF05070C),
                              Color(0xFF0A0D14),
                              Color(0xFF06080D),
                            ]
                          : const [
                              Color(0xFFF8FCFF),
                              Color(0xFFF0F6FB),
                              Color(0xFFF7FBF6),
                            ],
                    ),
                  ),
                ),
                if (style == BackgroundStyle.blob)
                  Positioned.fill(child: _BlobLayer(dark: dark))
                else
                  Positioned.fill(child: _OrbLayer(dark: dark)),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// The original "liquid glass" look: three soft round glows.
class _OrbLayer extends StatelessWidget {
  const _OrbLayer({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -30,
            child: _Orb(
              color: AppConstants.glowBlue,
              size: 220,
              alpha: dark ? 0.28 : 0.20,
            ),
          ),
          Positioned(
            top: 220,
            left: -50,
            child: _Orb(
              color: AppConstants.glowGreen,
              size: 200,
              alpha: dark ? 0.22 : 0.18,
            ),
          ),
          Positioned(
            bottom: 160,
            right: 0,
            child: _Orb(
              color: AppConstants.glowOrange,
              size: 160,
              alpha: 0.14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.alpha});

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final tinted = color.withValues(alpha: alpha);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tinted,
        boxShadow: [
          BoxShadow(color: tinted, blurRadius: 60, spreadRadius: 24),
        ],
      ),
    );
  }
}

/// Organic freeform "blob" shapes (à la Blobmaker) drifting behind the
/// content, softened with a blur so they read as ambient color the same
/// way the glow orbs do, rather than flat graphic-design cutouts.
class _BlobLayer extends StatelessWidget {
  const _BlobLayer({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final alpha = dark ? 0.30 : 0.22;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
      child: CustomPaint(
        painter: _BlobPainter(dark: dark, alpha: alpha),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.dark, required this.alpha});

  final bool dark;
  final double alpha;

  /// Fractional (0..1) control points, smoothed into a closed loop below —
  /// an irregular hand-placed hexagon-ish ring reads as an organic blob
  /// once every corner is rounded off by [_smoothClosedPath].
  static const _blobA = [
    Offset(0.18, -0.06),
    Offset(0.52, -0.10),
    Offset(0.74, 0.10),
    Offset(0.66, 0.42),
    Offset(0.34, 0.46),
    Offset(0.04, 0.26),
  ];

  static const _blobB = [
    Offset(0.30, 0.66),
    Offset(0.62, 0.60),
    Offset(0.96, 0.78),
    Offset(0.92, 1.12),
    Offset(0.56, 1.16),
    Offset(0.26, 0.96),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintBlob(
      canvas,
      size,
      _blobA,
      Alignment.topRight,
      Alignment.bottomLeft,
      [
        AppConstants.glowBlue.withValues(alpha: alpha),
        AppConstants.glowGreen.withValues(alpha: alpha * 0.8),
      ],
    );
    _paintBlob(
      canvas,
      size,
      _blobB,
      Alignment.bottomLeft,
      Alignment.topRight,
      [
        AppConstants.glowOrange.withValues(alpha: alpha),
        AppConstants.glowBlue.withValues(alpha: alpha * 0.7),
      ],
    );
    // A few small floating "bubbles" for extra depth, echoing the
    // reference art's scattered circles.
    _bubble(canvas, size, const Offset(0.86, 0.16), 0.05, AppConstants.glowGreen, alpha);
    _bubble(canvas, size, const Offset(0.10, 0.58), 0.035, AppConstants.glowOrange, alpha);
    _bubble(canvas, size, const Offset(0.70, 0.86), 0.04, AppConstants.glowBlue, alpha * 0.8);
  }

  void _paintBlob(
    Canvas canvas,
    Size size,
    List<Offset> fractionalPoints,
    Alignment from,
    Alignment to,
    List<Color> colors,
  ) {
    final points = [
      for (final p in fractionalPoints)
        Offset(p.dx * size.width, p.dy * size.height),
    ];
    final path = _smoothClosedPath(points);
    final rect = path.getBounds();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: from,
        end: to,
        colors: colors,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  void _bubble(
    Canvas canvas,
    Size size,
    Offset centerFraction,
    double radiusFraction,
    Color color,
    double alpha,
  ) {
    final center = Offset(
      centerFraction.dx * size.width,
      centerFraction.dy * size.height,
    );
    final radius = radiusFraction * size.shortestSide;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  /// Turns a handful of corner points into a smooth closed blob: each
  /// original point becomes a curve *control* point, and the path only
  /// actually passes through the midpoints between consecutive points —
  /// a cheap, well-known trick for organic shapes with no extra deps.
  Path _smoothClosedPath(List<Offset> pts) {
    final path = Path();
    final startMid = Offset.lerp(pts.last, pts.first, 0.5)!;
    path.moveTo(startMid.dx, startMid.dy);
    for (var i = 0; i < pts.length; i++) {
      final current = pts[i];
      final next = pts[(i + 1) % pts.length];
      final mid = Offset.lerp(current, next, 0.5)!;
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.alpha != alpha;
}
