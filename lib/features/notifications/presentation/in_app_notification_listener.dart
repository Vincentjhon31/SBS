import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../items/data/items_providers.dart';
import '../data/notifications_models.dart';
import '../data/notifications_providers.dart';

/// Wraps the whole app: whenever a new row lands in the signed-in user's
/// live notification stream — a reminder, an overdue alert, an
/// approval/rejection — this pops an in-app banner and plays one sound,
/// so it's noticed immediately instead of only surfacing once someone
/// happens to open the Notifications tab.
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
    final notification = _pending.removeAt(0);
    _dialogShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NotificationDialog(notification: notification),
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
    } else if (isStaff && notification.type == 'overdue') {
      router.go(AppRoutes.approvals);
    } else {
      router.go(AppRoutes.requests);
    }
  }
}

IconData _iconFor(String type) => switch (type) {
  'request_approved' => Icons.check_circle_outline,
  'request_rejected' => Icons.cancel_outlined,
  'due_soon' => Icons.schedule,
  'overdue' => Icons.warning_amber,
  'announcement' => Icons.campaign_outlined,
  _ => Icons.notifications_outlined,
};

/// Centered, non-auto-dismissing modal shown for each new notification —
/// replaces the old SnackBar "toast" which was easy to miss. Multiple
/// notifications arriving together are queued by the listener and shown
/// one at a time rather than stacking.
class _NotificationDialog extends StatelessWidget {
  const _NotificationDialog({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(notification.type),
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            notification.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            notification.body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            context
                .findAncestorStateOfType<_InAppNotificationListenerState>()
                ?._openNotification(notification);
          },
          child: const Text('View'),
        ),
      ],
    );
  }
}
