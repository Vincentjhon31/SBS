import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

abstract final class SBSTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.seedColor,
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
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      // Consistent, "iOS-feel" slide transition on every push/pop —
      // Cupertino's builder also grants the edge-swipe-to-go-back gesture.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
