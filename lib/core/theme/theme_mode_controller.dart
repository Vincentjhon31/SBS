import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'sbs_theme_mode';

/// Loads the persisted theme choice before the app builds, so there's no
/// light/dark flash on startup. Call once in main() before runApp.
Future<ThemeMode> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == raw,
    orElse: () => ThemeMode.system,
  );
}

class ThemeModeController extends Notifier<ThemeMode> {
  /// Set from main() (via [loadSavedThemeMode]) before the ProviderScope
  /// is built, since Notifier.build() must be synchronous.
  static ThemeMode initialMode = ThemeMode.system;

  @override
  ThemeMode build() => initialMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
