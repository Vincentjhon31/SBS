import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'sbs_background_style';

/// The glow-and-orbs "glossy" backdrop vs. a flat solid surface — a
/// device/session preference (like [ThemeMode]), not synced to the
/// account, since it's really a "turn off the fancy effects" toggle for
/// lower-end devices/browsers rather than an identity preference.
enum BackgroundStyle { glossy, solid }

/// Loads the persisted choice before the app builds, so there's no
/// glossy/solid flash on startup. Call once in main() before runApp.
Future<BackgroundStyle> loadSavedBackgroundStyle() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  return BackgroundStyle.values.firstWhere(
    (style) => style.name == raw,
    orElse: () => BackgroundStyle.glossy,
  );
}

class BackgroundStyleController extends Notifier<BackgroundStyle> {
  /// Set from main() (via [loadSavedBackgroundStyle]) before the
  /// ProviderScope is built, since Notifier.build() must be synchronous.
  static BackgroundStyle initialStyle = BackgroundStyle.glossy;

  @override
  BackgroundStyle build() => initialStyle;

  Future<void> setStyle(BackgroundStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, style.name);
  }
}

final backgroundStyleProvider =
    NotifierProvider<BackgroundStyleController, BackgroundStyle>(
      BackgroundStyleController.new,
    );
