import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/app_animations.dart';
import '../../items/data/items_providers.dart';
import '../data/notifications_models.dart';
import '../data/notifications_providers.dart';

/// Icon and accent for each notification type, shared by the modal, the
/// inbox list, and the web notification panel so one kind of event always
/// looks the same wherever it appears.
({IconData icon, Color color}) notificationStyle(
  String type,
  ColorScheme scheme,
) => switch (type) {
  'request_approved' => (
    icon: Icons.check_circle_outline,
    color: const Color(0xFF1F9D65),
  ),
  'request_rejected' => (icon: Icons.cancel_outlined, color: scheme.error),
  'due_soon' => (icon: Icons.schedule, color: const Color(0xFFE07A1F)),
  'overdue' => (icon: Icons.warning_amber_rounded, color: scheme.error),
  'announcement' => (
    icon: Icons.campaign_outlined,
    color: const Color(0xFFC2185B),
  ),
  _ => (icon: Icons.notifications_outlined, color: scheme.primary),
};

/// Wraps the whole app: whenever a new row lands in the signed-in user's
/// live notification stream — a reminder, an overdue alert, an
/// approval/rejection, a broadcast announcement — this pops a centered
/// modal and plays one sound, so it is noticed immediately instead of
/// only surfacing when someone opens the Notifications tab.
///
/// Applies to staff and citizens alike, on mobile and on the web
/// dashboard: approvers receive the overdue alerts for items they are
/// responsible for.
class InAppNotificationListener extends ConsumerStatefulWidget {
  const InAppNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState
    extends ConsumerState<InAppNotificationListener> {
  final _player = AudioPlayer();
  Set<String> _seenIds = {};
  bool _initialized = false;
  final _pending = <AppNotification>[];
  bool _dialogShowing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      previous,
      next,
    ) {
      final list = next.value;
      if (list == null) return;

      // The stream's first emission is whatever already existed before
      // this listener mounted (e.g. every notification from a prior
      // session) — record it as a baseline instead of alerting for all
      // of it at once on every app open.
      if (!_initialized) {
        _seenIds = {for (final n in list) n.id};
        _initialized = true;
        return;
      }

      final newOnes = [
        for (final n in list)
          if (!_seenIds.contains(n.id)) n,
      ];
      _seenIds = {for (final n in list) n.id};
      if (newOnes.isEmpty) return;

      unawaited(_player.play(AssetSource('conclusive-message-tone.mp3')));
      _pending.addAll(newOnes);
      _showNextIfIdle();
    });

    return widget.child;
  }

  void _showNextIfIdle() {
    if (_dialogShowing || _pending.isEmpty) return;
    // This widget lives in MaterialApp.router's builder, above the
    // router's Navigator, so its own context has no Navigator ancestor —
    // showDialog(context: context) throws a null-check error there.
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    final notification = _pending.removeAt(0);
    _dialogShowing = true;
    showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) => NotificationModal(
        notification: notification,
        queuedBehind: _pending.length,
        onView: () => _openNotification(notification),
      ),
    ).then((_) {
      _dialogShowing = false;
      if (!mounted) return;
      _showNextIfIdle();
    });
  }

  void _openNotification(AppNotification notification) {
    if (notification.unread) {
      ref.read(notificationsActionsProvider).markRead(notification.id);
    }
    final isStaff = ref.read(isStaffProvider);
    final router = ref.read(routerProvider);
    if (notification.type == 'announcement') {
      router.go(AppRoutes.notifications);
    } else if (isStaff) {
      // Staff never hold requests of their own — every alert they get is
      // about something waiting in their approval queue.
      router.go(AppRoutes.approvals);
    } else {
      router.go(AppRoutes.requests);
    }
  }
}

/// Centered, non-auto-dismissing modal shown for each new notification —
/// replaces the old SnackBar "toast", which was easy to miss. Several
/// arriving together are queued and shown one at a time rather than
/// stacking, with a note of how many are still waiting.
class NotificationModal extends StatelessWidget {
  const NotificationModal({
    super.key,
    required this.notification,
    required this.onView,
    this.queuedBehind = 0,
  });

  final AppNotification notification;
  final VoidCallback onView;

  /// How many more are waiting behind this one.
  final int queuedBehind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = notificationStyle(notification.type, scheme);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Two rings behind the glyph, tinted to the event type, so an
            // overdue alert reads as urgent at a glance and an approval
            // does not.
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 30, color: style.color),
                ),
              ),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              notification.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ).fadeUp(delay: const Duration(milliseconds: 70)),
            const SizedBox(height: 8),
            Text(
              notification.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ).fadeUp(delay: const Duration(milliseconds: 110)),
            if (queuedBehind > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  queuedBehind == 1
                      ? '1 more notification'
                      : '$queuedBehind more notifications',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).fadeUp(delay: const Duration(milliseconds: 150)),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(queuedBehind > 0 ? 'Next' : 'Dismiss'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: style.color,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            onView();
          },
          child: const Text('View'),
        ),
      ],
    );
  }
}
