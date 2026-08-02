import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../items/data/items_providers.dart';
import '../data/notifications_models.dart';
import '../data/notifications_providers.dart';
import 'in_app_notification_listener.dart';

/// The inbox behind the bell. Grouped by day rather than one flat list —
/// these arrive in bursts (a batch of due-soon reminders, a broadcast),
/// and undated rows make it hard to tell this morning's alerts from last
/// week's.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(notificationsActionsProvider).markAllRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: GlossyBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: switch (notifications) {
                AsyncData(:final value) when value.isEmpty =>
                  const _EmptyInbox(),
                AsyncData(:final value) => _Inbox(
                  notifications: value,
                  unread: unread,
                ),
                AsyncError() => const _EmptyInbox(
                  icon: Icons.error_outline,
                  title: 'Could not load notifications',
                  hint: 'Check your connection and pull down to retry.',
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Inbox extends ConsumerWidget {
  const _Inbox({required this.notifications, required this.unread});

  final List<AppNotification> notifications;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Flattened into a single list of headers and rows so the whole
    // inbox stays one lazily-built ListView.
    final rows = <Widget>[];
    String? lastBucket;
    for (var i = 0; i < notifications.length; i++) {
      final n = notifications[i];
      final bucket = _dayBucket(n.sentAt);
      if (bucket != lastBucket) {
        lastBucket = bucket;
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(20, rows.isEmpty ? 8 : 22, 20, 8),
            child: Text(
              bucket.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _NotificationCard(notification: n),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 17,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    unread == 1
                        ? '1 unread notification'
                        : '$unread unread notifications',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ).fadeUp(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i].fadeUpAt(i),
            ),
          ),
        ),
      ],
    );
  }

  static String _dayBucket(DateTime dt) {
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'Earlier this week';
    return formatDate(dt);
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = notificationStyle(notification.type, scheme);
    final unread = notification.unread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context, ref),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Unread rows get a tinted surface and a leading accent bar
            // rather than only bold text — a weight change alone is easy
            // to miss when scanning a long inbox.
            color: unread
                ? style.color.withValues(alpha: 0.06)
                : scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? style.color.withValues(alpha: 0.32)
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(style.icon, size: 20, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: style.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      formatRelative(notification.sentAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    if (notification.unread) {
      ref.read(notificationsActionsProvider).markRead(notification.id);
    }
    // Announcements are standalone — there is no request behind them, so
    // tapping one just marks it read and stays put.
    if (notification.type == 'announcement') return;
    final isStaff = ref.read(isStaffProvider);
    context.go(isStaff ? AppRoutes.approvals : AppRoutes.requests);
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({
    this.icon = Icons.notifications_none,
    this.title = 'No notifications yet',
    this.hint =
        'Approvals, return reminders, and LGU announcements will show up '
            'here.',
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.onSurfaceVariant),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ).fadeUp(delay: const Duration(milliseconds: 80)),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ).fadeUp(delay: const Duration(milliseconds: 130)),
          ],
        ),
      ),
    );
  }
}
