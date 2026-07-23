import 'package:flutter/material.dart';

/// Soft, blurred color flares behind the main tab screens — replaces a flat
/// white/black background with gentle depth. Content (cards, list tiles)
/// stays fully opaque on top; only empty space shows the flare.
class GlossyBackground extends StatelessWidget {
  const GlossyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      child: Stack(
        // Loose fit (the default) gives non-positioned children — i.e.
        // [child] — their own natural size instead of filling the
        // screen, which silently breaks any Expanded/Flexible inside it
        // (as in the sidebar shell's Row). Force it to fill so [child]
        // always gets real bounded constraints.
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: _Flare(color: scheme.primary, size: 340),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _Flare(color: scheme.tertiary, size: 320),
          ),
          child,
        ],
      ),
    );
  }
}

class _Flare extends StatelessWidget {
  const _Flare({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opacity = dark ? 0.30 : 0.16;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
