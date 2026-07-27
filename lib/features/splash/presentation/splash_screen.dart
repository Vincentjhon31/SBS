import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';

/// Branded fallback shown while the router resolves the auth redirect (the
/// native splash covers actual cold start). The logo + wordmark fade and
/// scale in, then the logo settles into a slow "breathing" pulse and three
/// dots wave beneath it, so the brief wait clearly reads as "loading" and
/// not a stalled/blank frame.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _entry.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlossyBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: _entry,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_entry.value);
                    return Opacity(
                      opacity: t.clamp(0, 1),
                      child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _loop,
                        builder: (context, child) {
                          // A slow, subtle breathing pulse once the entry
                          // animation has settled — never fully static.
                          final pulse =
                              0.5 + 0.5 * (1 - (2 * _loop.value - 1).abs());
                          final scale = 1.0 + 0.035 * pulse;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: const AppLogoBadge(size: 140),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.appFullName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: Column(
                  children: [
                    _LoadingDots(animation: _loop, color: scheme.primary),
                    const SizedBox(height: 14),
                    Text(
                      'LGU Borrowing System',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots that wave up and down in sequence — a small, simple "still
/// working" cue that reads clearly at a glance, cheaper than a spinner and
/// friendlier than a static row of dots.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // Each dot's bounce is offset by a third of the loop, so
                // they wave left-to-right rather than pulsing in unison.
                final phase = (animation.value + i / 3) % 1.0;
                final lift = 1 - (2 * phase - 1).abs();
                return Transform.translate(
                  offset: Offset(0, -6 * lift),
                  child: child,
                );
              },
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
