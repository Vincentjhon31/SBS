import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/data/auth_providers.dart';

/// The active accent seed color, derived from the signed-in user's
/// server-synced preference (defaults to civic blue when signed out,
/// loading, or unset).
final seedColorProvider = Provider<Color>((ref) {
  final profile = ref.watch(myProfileProvider).value;
  return switch (profile?.themeColor) {
    'purple' => AppConstants.purpleSeedColor,
    _ => AppConstants.seedColor,
  };
});

abstract final class SBSTheme {
  static ThemeData light(Color seed) => _base(seed, Brightness.light);

  static ThemeData dark(Color seed) => _base(seed, Brightness.dark);

  static ThemeData _base(Color seed, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
