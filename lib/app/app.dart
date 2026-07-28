import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/accent_color_provider.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/notifications/presentation/in_app_notification_listener.dart';
import 'router.dart';
import 'theme.dart';

class SBSApp extends ConsumerWidget {
  const SBSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final seed = ref.watch(seedColorProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: SBSTheme.light(seed: seed),
      darkTheme: SBSTheme.dark(seed: seed),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          InAppNotificationListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
