import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/glossy_background.dart';

/// Branded fallback shown only while the router resolves the auth redirect;
/// the native splash covers actual app startup. Matches the native splash:
/// the full-color logo on the same glossy backdrop used across the app.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlossyBackground(
        child: Center(
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
      ),
    );
  }
}
