import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared motion vocabulary, so every screen animates the same way rather
/// than each one inventing its own durations and curves.
///
/// The rules this encodes:
/// - Entrances only. Nothing loops or draws attention to itself once the
///   screen has settled — this is a government service, not a showcase.
/// - Short and shallow: ~360ms and a 12-16px travel. Long, far-travelling
///   motion makes an app feel slow no matter how smooth it is.
/// - Lists stagger by index with a cap, so a 200-row registry does not
///   take ten seconds to finish arriving.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 220);
  static const normal = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 520);

  /// Per-item stagger step in a list or grid.
  static const stagger = Duration(milliseconds: 55);

  /// Never delay an item by more than this, however far down it sits —
  /// beyond ~8 items the stagger has already read as a cascade, and the
  /// rest should just appear.
  static const maxStaggerSteps = 8;

  static const enter = Curves.easeOutCubic;

  /// Delay for the item at [index] in a staggered run.
  static Duration staggerFor(int index) =>
      stagger * index.clamp(0, maxStaggerSteps);
}

extension AppAnimateX on Widget {
  /// The default entrance: fade up a short distance. Use for cards,
  /// tiles, list rows, and section blocks.
  Animate fadeUp({Duration? delay, double distance = 0.14}) => animate()
      .fadeIn(duration: AppMotion.normal, delay: delay, curve: AppMotion.enter)
      .moveY(
        begin: distance * 100,
        end: 0,
        duration: AppMotion.normal,
        delay: delay,
        curve: AppMotion.enter,
      );

  /// Same as [fadeUp] but staggered by position in a list.
  Animate fadeUpAt(int index, {double distance = 0.14}) =>
      fadeUp(delay: AppMotion.staggerFor(index), distance: distance);

  /// A gentler fade with no travel — for large surfaces (headers, hero
  /// panels) where sliding a big block looks heavy.
  Animate softFade({Duration? delay}) =>
      animate().fadeIn(duration: AppMotion.slow, delay: delay);

  /// Scale + fade, for a single focal element such as a logo or an empty
  /// state illustration.
  Animate popIn({Duration? delay}) => animate()
      .fadeIn(duration: AppMotion.normal, delay: delay)
      .scale(
        begin: const Offset(0.92, 0.92),
        end: const Offset(1, 1),
        duration: AppMotion.normal,
        delay: delay,
        curve: AppMotion.enter,
      );

  /// Slides in from the left — used for sidebar/rail items.
  Animate slideInLeft({Duration? delay}) => animate()
      .fadeIn(duration: AppMotion.fast, delay: delay)
      .moveX(
        begin: -14,
        end: 0,
        duration: AppMotion.normal,
        delay: delay,
        curve: AppMotion.enter,
      );
}
