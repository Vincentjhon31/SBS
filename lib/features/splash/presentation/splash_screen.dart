import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Branded fallback shown only while the router resolves the auth redirect;
/// the native splash covers actual app startup. Matches the native splash:
/// the full-color logo on a plain light/dark surface.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppConstants.logoAsset, height: 160),
            const SizedBox(height: 8),
            Text(
              AppConstants.appFullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
