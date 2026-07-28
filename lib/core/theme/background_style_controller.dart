import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/settings/data/settings_providers.dart';

const _prefsKey = 'sbs_background_style';

/// The glow-and-orbs "glossy" backdrop, organic "blob" shapes, or a flat
/// solid surface. Cached locally (so pre-auth screens like login/splash
/// have something to paint immediately) but also synced with
/// `profiles.background_style`, so a signed-in user's choice follows them
/// across devices — the local cache is just a fast/offline fallback.
enum BackgroundStyle { glossy, blob, solid }

/// Loads the persisted choice before the app builds, so there's no
/// glossy/solid flash on startup. Call once in main() before runApp.
Future<BackgroundStyle> loadSavedBackgroundStyle() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  return BackgroundStyle.values.firstWhere(
    (style) => style.name == raw,
    orElse: () => BackgroundStyle.blob,
  );
}

class BackgroundStyleController extends Notifier<BackgroundStyle> {
  /// Set from main() (via [loadSavedBackgroundStyle]) before the
  /// ProviderScope is built, since Notifier.build() must be synchronous.
  static BackgroundStyle initialStyle = BackgroundStyle.blob;

  @override
  BackgroundStyle build() {
    // Adopt the DB value whenever the signed-in profile loads/changes, so
    // switching devices brings the user's choice with them.
    ref.listen<AsyncValue<Profile?>>(myProfileProvider, (previous, next) {
      final value = next.value?.backgroundStyle;
      if (value != null) unawaited(_adoptFromProfile(value));
    });
    return initialStyle;
  }

  Future<void> _adoptFromProfile(String value) async {
    final style = BackgroundStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BackgroundStyle.blob,
    );
    if (style == state) return;
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, style.name);
  }

  Future<void> setStyle(BackgroundStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, style.name);
    // Best-effort account sync — signed-out users (e.g. still on the
    // login screen) just keep the local/device preference.
    if (ref.read(supabaseClientProvider).auth.currentUser != null) {
      await ref.read(settingsRepositoryProvider).updateBackgroundStyle(style.name);
    }
  }
}

final backgroundStyleProvider =
    NotifierProvider<BackgroundStyleController, BackgroundStyle>(
      BackgroundStyleController.new,
    );
