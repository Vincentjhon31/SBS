import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';

/// Branded fallback shown while the router resolves the auth redirect (the
/// native splash covers actual cold start).
///
/// The entrance is staggered rather than one blanket fade — a halo blooms
/// behind the mark, the logo settles in, then the wordmark and tagline
/// rise under it. Once settled, two soft rings ping outward and a slim
/// indeterminate bar sweeps at the foot, so the wait reads as "working"
/// instead of a stalled frame.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// Staggered slices of [_entry] — each element starts after the one
  /// before it has begun settling, which reads as a considered sequence
  /// rather than everything arriving at once.
  late final _haloIn = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );
  late final _logoIn = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.05, 0.65, curve: Curves.easeOutBack),
  );
  late final _wordmarkIn = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
  );
  late final _taglineIn = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.5, 0.92, curve: Curves.easeOutCubic),
  );
  late final _footerIn = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rings ping outward from behind the mark.
                          FadeTransition(
                            opacity: _haloIn,
                            child: AnimatedBuilder(
                              animation: _loop,
                              builder: (context, _) => CustomPaint(
                                size: const Size.square(260),
                                painter: _PulseRingPainter(
                                  progress: _loop.value,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                          // Soft glow bloom directly under the logo.
                          FadeTransition(
                            opacity: _haloIn,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.18),
                                    scheme.primary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.72,
                              end: 1.0,
                            ).animate(_logoIn),
                            child: FadeTransition(
                              opacity: _logoIn,
                              child: AnimatedBuilder(
                                animation: _loop,
                                builder: (context, child) {
                                  // Slow breathing so the mark is never
                                  // perfectly still.
                                  final breathe =
                                      1 - (2 * _loop.value - 1).abs();
                                  return Transform.scale(
                                    scale: 1 + 0.022 * breathe,
                                    child: child,
                                  );
                                },
                                child: const AppLogoBadge(size: 132),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RiseIn(
                      animation: _wordmarkIn,
                      child: Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _RiseIn(
                      animation: _taglineIn,
                      child: Text(
                        AppConstants.appFullName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: FadeTransition(
                  opacity: _footerIn,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 168,
                        child: _SweepBar(
                          animation: _loop,
                          color: scheme.primary,
                          track: scheme.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Municipality of Bongabong',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
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
    );
  }
}

/// Fades a child in while lifting it a few pixels — the shared entrance
/// for the wordmark and tagline.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - animation.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Two concentric rings expanding out of the logo and fading as they go,
/// offset half a cycle apart so there is always one in flight.
class _PulseRingPainter extends CustomPainter {
  const _PulseRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const minRadius = 72.0;
    final maxRadius = size.width / 2;

    for (var i = 0; i < 2; i++) {
      final t = (progress + i * 0.5) % 1.0;
      final eased = Curves.easeOutCubic.transform(t);
      final radius = minRadius + (maxRadius - minRadius) * eased;
      // Fades as it travels; also eased in at the very start so a ring
      // never pops into existence at full strength.
      final alpha = (1 - eased) * 0.30 * math.min(1.0, t * 6);
      if (alpha <= 0.002) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Slim indeterminate bar: a short highlight sweeps along a faint track.
/// Deliberately not a CircularProgressIndicator — this reads as brand
/// motion rather than a system spinner.
class _SweepBar extends StatelessWidget {
  const _SweepBar({
    required this.animation,
    required this.color,
    required this.track,
  });

  final Animation<double> animation;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    const fraction = 0.42;
                    // Travels from fully off the left to fully off the
                    // right, so the highlight enters and exits cleanly.
                    final travel = width * (1 + fraction);
                    final x =
                        -width * fraction +
                        travel * Curves.easeInOut.transform(animation.value);
                    return Stack(
                      children: [
                        Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          width: width * fraction,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.0),
                                  color,
                                  color.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
