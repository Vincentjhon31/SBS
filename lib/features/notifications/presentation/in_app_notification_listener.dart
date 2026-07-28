import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      for (final n in newOnes) {
        _showBanner(n);
      }
    });

    return widget.child;
  }

  void _showBanner(AppNotification notification) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final icon = switch (notification.type) {
      'request_approved' => Icons.check_circle_outline,
      'request_rejected' => Icons.cancel_outlined,
      'due_soon' => Icons.schedule,
      'overdue' => Icons.warning_amber,
      _ => Icons.notifications_outlined,
    };
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openNotification(notification),
        ),
      ),
    );
  }

  void _openNotification(AppNotification notification) {
    if (notification.unread) {
      ref.read(notificationsActionsProvider).markRead(notification.id);
    }
    final isStaff = ref.read(isStaffProvider);
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (isStaff && notification.type == 'overdue') {
      router.go(AppRoutes.approvals);
    } else {
      router.go(AppRoutes.requests);
    }
  }
}
