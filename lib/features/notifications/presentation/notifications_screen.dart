import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_models.dart';
import '../data/notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsActionsProvider).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: switch (notifications) {
        AsyncData(:final value) when value.isEmpty => const Center(
            child: Text('No notifications yet.'),
          ),
        AsyncData(:final value) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _NotificationTile(notification: value[index]),
          ),
        AsyncError() =>
          const Center(child: Text('Could not load notifications.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (notification.type) {
      'request_approved' => Icons.check_circle_outline,
      'request_rejected' => Icons.cancel_outlined,
      'due_soon' => Icons.schedule,
      'overdue' => Icons.warning_amber,
      _ => Icons.notifications_outlined,
    };

    return ListTile(
      leading: Icon(
        icon,
        color: notification.type == 'overdue' ? scheme.error : scheme.primary,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: notification.unread
          ? Icon(Icons.circle, size: 10, color: scheme.primary)
          : null,
      isThreeLine: true,
      onTap: notification.unread
          ? () =>
              ref.read(notificationsActionsProvider).markRead(notification.id)
          : null,
    );
  }
}
