import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft, blurred color glow behind the main screens: a subtle tonal
/// gradient plus three real-blurred accent orbs (primary/secondary/
/// tertiary) — the same "liquid glass" depth used elsewhere in the LGU
/// app family, adapted to draw its palette from the active ColorScheme
/// (rather than hardcoded hex) so it tracks both light/dark mode and
/// the blue/purple accent switch in Settings.
///
/// The blur is applied once to a static orb layer, not as a live
/// BackdropFilter over scrolling content — cheap enough to leave on for
/// every screen, including on the web build.
class GlossyBackground extends StatelessWidget {
  const GlossyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      // Loose fit (the default) gives non-positioned children — i.e.
      // [child] — their own natural size instead of filling the
      // screen, which silently breaks any Expanded/Flexible inside it
      // (as in the sidebar shell's Row). Force it to fill so [child]
      // always gets real bounded constraints.
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.surface,
                        scheme.surfaceContainerLow,
                        scheme.surface,
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -120,
                          right: -90,
                          child: _Orb(
                            color: scheme.primary,
                            size: 300,
                            dark: dark,
                          ),
                        ),
                        Positioned(
                          top: 260,
                          left: -110,
                          child: _Orb(
                            color: scheme.tertiary,
                            size: 260,
                            dark: dark,
                          ),
                        ),
                        Positioned(
                          bottom: -140,
                          right: -40,
                          child: _Orb(
                            color: scheme.secondary,
                            size: 240,
                            dark: dark,
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
  const _Orb({required this.color, required this.size, required this.dark});

  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: dark ? 0.34 : 0.22),
      ),
    );
  }
}
