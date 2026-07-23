import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/theme_mode_controller.dart';
import 'router.dart';
import 'theme.dart';

class SBSApp extends ConsumerWidget {
  const SBSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: SBSTheme.light(seedColor),
      darkTheme: SBSTheme.dark(seedColor),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
