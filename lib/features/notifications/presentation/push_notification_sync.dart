import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_providers.dart';
import '../data/push_notification_service.dart';
import '../data/push_providers.dart';

/// Wraps the whole app (alongside `InAppNotificationListener`): initializes
/// FCM once, then keeps the device's `user-<uid>` topic subscription in
/// sync with whoever is currently signed in — this is how the backend
/// pushes to a specific user without needing a device-token table.
///
/// Reads the uid only from `authStateChangesProvider` (never
/// `supabaseClientProvider` directly), same as every other widget here —
/// that's the provider widget tests override, so this stays testable
/// without a live Supabase instance.
class PushNotificationSync extends ConsumerStatefulWidget {
  const PushNotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationSync> createState() =>
      _PushNotificationSyncState();
}

class _PushNotificationSyncState extends ConsumerState<PushNotificationSync> {
  String? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(pushNotificationServiceProvider).initialize());
  }

  Future<void> _syncTopic(String? uid) async {
    if (uid == _subscribedUserId) return;
    final service = ref.read(pushNotificationServiceProvider);

    final previousUid = _subscribedUserId;
    _subscribedUserId = uid;
    if (previousUid != null) {
      await service.unsubscribeFromTopic(userTopic(previousUid));
    }
    if (uid != null) {
      await service.subscribeToTopic(userTopic(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (
      previous,
      next,
    ) {
      unawaited(_syncTopic(next.value?.session?.user.id));
    });
    return widget.child;
  }
}
