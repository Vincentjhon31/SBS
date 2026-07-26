import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// The app logo shown as a rounded-square "badge" — a hard rounded clip
/// plus a soft shadow, so it reads as the app icon (matching the rounded
/// launcher icon) wherever it's shown at size: the login and splash
/// screens. Forcing the rounded clip here means the badge is always
/// rounded regardless of the source image's own corners.
class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage(AppConstants.logoAsset),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
