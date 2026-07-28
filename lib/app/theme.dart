import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

abstract final class SBSTheme {
  static ThemeData light({Color seed = AppConstants.seedColor}) =>
      _base(Brightness.light, seed);

  static ThemeData dark({Color seed = AppConstants.seedColor}) =>
      _base(Brightness.dark, seed);

  static ThemeData _base(Brightness brightness, Color seed) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Flat canvas behind the liquid-glass backdrop (matches eBongabong).
      scaffoldBackgroundColor:
          isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
      // Opaque surface background — NOT transparent. A transparent AppBar
      // only reveals whatever is painted behind the route, and the glossy
      // backdrop lives in each screen's body, not behind the app bar, so a
      // transparent bar fell through to a black void: fine in dark mode
      // (light text on black), invisible in light mode (dark text on
      // black). `surface` matches the top of the glossy gradient, so the
      // bar still reads as part of the backdrop while staying legible in
      // both modes. iconTheme/actionsIconTheme are set explicitly (not just
      // via foregroundColor) so the back arrow and action icons reliably
      // take onSurface.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        // A transparent AppBar leaves Flutter to guess the status-bar icon
        // brightness, which on Android can render the top strip's icons the
        // wrong color (light-on-light) when the app is forced to light mode
        // while the device is in dark mode. Pin it to the theme's brightness
        // so the status bar always contrasts with the light/dark surface.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Filled, not just outlined — an unfilled field over the glossy/blob
      // backdrop let the busy background show straight through it, reading
      // as a broken/transparent box rather than an input.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      // Smooth, modern "fade forwards" push/pop on every platform — the
      // current Material 3 motion (a gentle fade + slide), which reads far
      // less abrupt than a hard slide and matches the eBongabong app's feel.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
