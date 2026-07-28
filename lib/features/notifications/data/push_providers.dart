import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_notification_service.dart';

/// Set once in main.dart, before `runApp`, based on whether
/// `Firebase.initializeApp()` succeeded — same "static field read by a
/// provider" pattern as `ThemeModeController.initialMode` and
/// `BackgroundStyleController.initialStyle`. Android gets real FCM push;
/// web (or any platform where init failed) falls back to a no-op.
abstract final class FirebaseReadyController {
  static bool value = false;
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  if (FirebaseReadyController.value) {
    return FirebasePushNotificationService();
  }
  return const NoopPushNotificationService();
});
