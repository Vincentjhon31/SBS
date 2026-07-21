import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'notifications_models.dart';

/// Live inbox: realtime stream of the signed-in user's notifications,
/// newest first. RLS guarantees only the recipient's rows arrive.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const Stream.empty();
  return client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', uid)
      .order('sent_at')
      .map((rows) => [for (final row in rows) AppNotification.fromJson(row)]);
});

final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => n.unread).length;
});

class NotificationsActions {
  NotificationsActions(this._ref);

  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref
        .read(supabaseClientProvider)
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', uid)
        .isFilter('read_at', null);
  }
}

final notificationsActionsProvider =
    Provider<NotificationsActions>((ref) => NotificationsActions(ref));
