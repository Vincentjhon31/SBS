import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../constants/app_constants.dart';

/// The Material seed color, derived straight from the signed-in profile's
/// `theme_color` — unlike [BackgroundStyle], this needs no local device
/// cache: pre-auth screens (login/splash) just show the default blue until
/// a profile loads, which is the desired branding anyway.
final seedColorProvider = Provider<Color>((ref) {
  final themeColor = ref.watch(myProfileProvider).value?.themeColor;
  return AppConstants.accentSeedColors[themeColor] ?? AppConstants.seedColor;
});
