import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The channel FCM push notifications land in on Android — matches the
/// `default_notification_channel_id` meta-data in AndroidManifest.xml, so
/// background/terminated pushes (delivered natively by FCM, no Dart code
/// involved) use the same importance and sound as this channel.
const AndroidNotificationChannel pushNotificationChannel =
    AndroidNotificationChannel(
      'sbs_notifications',
      'SBS notifications',
      description:
          'Reminders, overdue alerts, and approval updates from SBS.',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

/// Topic a signed-in user's device subscribes to so the backend can push to
/// them by user id alone — no per-device token table needed.
String userTopic(String userId) => 'user-$userId';

/// Topic every device subscribes to, used to announce new app releases.
const appUpdatesTopic = 'app-updates';

abstract class PushNotificationService {
  Future<void> initialize();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// The `InAppNotificationListener` (Realtime + toast + sound) already covers
/// the "app is open" case, so this service deliberately does NOT register a
/// `FirebaseMessaging.onMessage` foreground handler — that would show the
/// same alert twice. Its only job is enabling background/terminated
/// delivery (permission + notification channel) and topic subscriptions.
class FirebasePushNotificationService implements PushNotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    await _messaging.requestPermission();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(pushNotificationChannel);

    await _messaging.subscribeToTopic(appUpdatesTopic);
  }

  @override
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);
}

/// Used on web (no Android channel/FCM push there) and if Firebase init
/// fails — the app still works, it just won't get background push.
class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
}
