import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../theme/background_style_controller.dart';

/// The "liquid glass" backdrop shared with the eBongabong Calendar app: a
/// soft vertical gradient plus three real-blurred glow orbs in a varied
/// blue/green/orange set (not shades of one accent), so the glow reads as
/// gentle ambient color behind opaque cards and list tiles.
///
/// Users can switch to a flat surface in Settings → Appearance (a device/
/// session preference) for lower-end devices/browsers. Either way the blur
/// is baked once into a static, cached layer — not a live BackdropFilter
/// over scrolling content — so it stays cheap even when left on.
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
                Positioned.fill(
                  child: ImageFiltered(
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
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
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
