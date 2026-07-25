import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/background_style_controller.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/theme/view_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  ThemeModeController.initialMode = await loadSavedThemeMode();
  BackgroundStyleController.initialStyle = await loadSavedBackgroundStyle();
  ViewModeController.initial = await loadSavedViewMode();
  runApp(const ProviderScope(child: SBSApp()));
}
