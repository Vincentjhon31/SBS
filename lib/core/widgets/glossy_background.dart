import 'dart:ui';

import 'package:blobs/blobs.dart';
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

/// Three true organic blobs (the `blobs` package's own irregular-polygon
/// generator, not a hand-rolled approximation), each gently morphing in
/// place on a slow loop — a bare minimum of motion, not an active
/// animation. Positioned upper-right, lower-left, and middle-left,
/// mirroring the glossy backdrop's three-glow layout.
class _BlobLayer extends StatelessWidget {
  const _BlobLayer({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    // A flat pastel colour reads as pastel on the light backdrop but as a
    // deep, muted jewel tone once blended over the near-black dark
    // backdrop — so the same alpha works for both, no separate dark
    // palette needed.
    final alpha = dark ? 0.55 : 0.75;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final base = (side.isFinite ? side * 0.62 : 320.0).clamp(220.0, 420.0);
        final height = constraints.biggest.height;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -base * 0.22,
              right: -base * 0.22,
              child: _GradientBlob(
                size: base,
                colors: const [AppConstants.pastelSky, AppConstants.pastelMint],
                alpha: alpha,
              ),
            ),
            Positioned(
              bottom: -base * 0.24,
              left: -base * 0.26,
              child: _GradientBlob(
                size: base * 0.92,
                colors: const [AppConstants.pastelPeach, AppConstants.pastelCoral],
                alpha: alpha * 0.9,
              ),
            ),
            Positioned(
              top: height.isFinite ? height / 2 - base * 0.35 : null,
              left: -base * 0.32,
              child: _GradientBlob(
                size: base * 0.8,
                colors: const [AppConstants.pastelLavender, AppConstants.pastelPink],
                alpha: alpha * 0.85,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GradientBlob extends StatelessWidget {
  const _GradientBlob({
    required this.size,
    required this.colors,
    required this.alpha,
  });

  final double size;
  final List<Color> colors;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final gradientColors = [for (final c in colors) c.withValues(alpha: alpha)];
    return Blob.animatedRandom(
      size: size,
      edgesCount: 9,
      minGrowth: 4,
      // Slow morph = "minimum" movement, a gentle wobble rather than an
      // active reshape.
      duration: const Duration(seconds: 7),
      loop: true,
      styles: BlobStyles(
        fillType: BlobFillType.fill,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ).createShader(Rect.fromLTWH(0, 0, size, size)),
      ),
    );
  }
}
