import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/settings/data/settings_providers.dart';

const _prefsKey = 'sbs_theme_mode';

/// Light unless the user says otherwise.
///
/// This used to default to [ThemeMode.system], which meant a phone on a
/// night schedule flipped the app to dark on its own — from the user's
/// side, indistinguishable from the app forgetting their choice. SBS is a
/// daytime counter tool, so light is the sensible floor and dark stays one
/// tap away in Settings.
const _defaultMode = ThemeMode.light;

/// Loads the persisted theme choice before the app builds, so there's no
/// light/dark flash on startup. Call once in main() before runApp.
Future<ThemeMode> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == raw,
    orElse: () => _defaultMode,
  );
}

/// Device cache plus account sync, mirroring BackgroundStyleController.
///
/// The local copy is what paints the pre-auth screens instantly; the
/// profile column is what makes the choice follow the user onto a new
/// device or browser. Previously this was device-only, so signing in
/// anywhere new inherited that machine's OS setting rather than the mode
/// the user had actually picked.
class ThemeModeController extends Notifier<ThemeMode> {
  /// Set from main() (via [loadSavedThemeMode]) before the ProviderScope
  /// is built, since Notifier.build() must be synchronous.
  static ThemeMode initialMode = _defaultMode;

  @override
  ThemeMode build() {
    ref.listen<AsyncValue<Profile?>>(myProfileProvider, (previous, next) {
      final value = next.value?.themeMode;
      if (value != null) unawaited(_adoptFromProfile(value));
    });
    return initialMode;
  }

  Future<void> _adoptFromProfile(String value) async {
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => _defaultMode,
    );
    if (mode == state) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
    // Best-effort account sync — signed-out users (still on login/splash)
    // just keep the device preference.
    if (ref.read(supabaseClientProvider).auth.currentUser != null) {
      await ref.read(settingsRepositoryProvider).updateThemeMode(mode.name);
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
