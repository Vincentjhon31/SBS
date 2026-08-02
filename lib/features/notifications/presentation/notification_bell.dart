import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../../items/data/items_providers.dart';
import '../data/notifications_models.dart';
import '../data/notifications_providers.dart';
import 'in_app_notification_listener.dart';

/// Top-bar bell for the staff web dashboard.
///
/// Opens the recent notifications in an anchored panel rather than
/// navigating away — an approver checking an overdue alert should not
/// lose the queue they were working through. The full inbox is one click
/// further, for anything older than the last handful.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  static const _previewCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final recent = ref.watch(notificationsProvider).value ?? const [];

    return PopupMenuButton<void>(
      tooltip: 'Notifications',
      offset: const Offset(0, 52),
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 380),
      position: PopupMenuPosition.under,
      icon: Badge.count(
        count: unread,
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _Panel(
            notifications: recent.take(_previewCount).toList(),
            unread: unread,
            total: recent.length,
          ),
        ),
      ],
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.notifications,
    required this.unread,
    required this.total,
  });

  final List<AppNotification> notifications;
  final int unread;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unread',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (unread > 0)
                TextButton(
                  onPressed: () {
                    ref.read(notificationsActionsProvider).markAllRead();
                    Navigator.pop(context);
                  },
                  child: const Text('Mark all read'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (notifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 30,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nothing yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Overdue alerts and announcements land here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final (i, n) in notifications.indexed)
            _PanelRow(notification: n).fadeUpAt(i),
        const Divider(height: 1),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.push(AppRoutes.notifications);
          },
          child: Text(
            total > notifications.length
                ? 'View all $total notifications'
                : 'View all notifications',
          ),
        ),
      ],
    );
  }
}

class _PanelRow extends ConsumerWidget {
  const _PanelRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = notificationStyle(notification.type, scheme);
    final unread = notification.unread;

    return InkWell(
      onTap: () {
        if (unread) {
          ref.read(notificationsActionsProvider).markRead(notification.id);
        }
        Navigator.pop(context);
        if (notification.type == 'announcement') {
          context.push(AppRoutes.notifications);
          return;
        }
        final isStaff = ref.read(isStaffProvider);
        context.go(isStaff ? AppRoutes.approvals : AppRoutes.requests);
      },
      child: Container(
        color: unread ? style.color.withValues(alpha: 0.05) : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, size: 17, color: style.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatRelative(notification.sentAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 6),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
