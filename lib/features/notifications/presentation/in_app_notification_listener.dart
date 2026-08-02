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

  /// Only notifications sent after this moment are worth interrupting for.
  ///
  /// The id baseline below is not enough on its own: the stream's first
  /// emission can arrive empty or partial (before data loads, or right
  /// after sign-in), which made every existing row look brand new and
  /// popped a modal for each — including ones already read weeks ago.
  /// Anything older than the session belongs in the inbox, not in front
  /// of the user.
  final _startedAt = DateTime.now();

  /// Past this many at once, one summary modal replaces the queue — a
  /// broadcast to a citizen with a backlog should never mean tapping
  /// "Next" a hundred times.
  static const _summaryThreshold = 3;

  /// Realtime delivers one emission per inserted row, so a burst arrives
  /// as N separate callbacks rather than a single list. Without this
  /// pause the first row would open its own modal before the rest turned
  /// up, and the summary below could never trigger.
  Timer? _burstTimer;
  static const _burstWindow = Duration(milliseconds: 700);

  @override
  void dispose() {
    _burstTimer?.cancel();
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
          if (!_seenIds.contains(n.id) &&
              n.unread &&
              n.sentAt.isAfter(_startedAt))
            n,
      ];
      _seenIds = {for (final n in list) n.id};
      if (newOnes.isEmpty) return;

      _pending.addAll(newOnes);
      // Let the rest of the burst land before deciding how to present it,
      // and chime once for the batch rather than once per row.
      _burstTimer?.cancel();
      _burstTimer = Timer(_burstWindow, () {
        if (!mounted) return;
        unawaited(_player.play(AssetSource('conclusive-message-tone.mp3')));
        _showNextIfIdle();
      });
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

    _dialogShowing = true;

    // A burst collapses into one summary rather than a queue to tap
    // through. The individual modal below also offers "Dismiss all", so
    // even a queue of three is never a trap.
    if (_pending.length > _summaryThreshold) {
      final count = _pending.length;
      _pending.clear();
      showDialog<void>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (context) => _NotificationSummaryModal(
          count: count,
          onView: _openInbox,
        ),
      ).then(_onDialogClosed);
      return;
    }

    final notification = _pending.removeAt(0);
    showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) => NotificationModal(
        notification: notification,
        queuedBehind: _pending.length,
        onView: () => _openNotification(notification),
        onDismissAll: _pending.isEmpty ? null : _pending.clear,
      ),
    ).then(_onDialogClosed);
  }

  void _onDialogClosed(void _) {
    _dialogShowing = false;
    if (!mounted) return;
    _showNextIfIdle();
  }

  void _openInbox() => ref.read(routerProvider).go(AppRoutes.notifications);

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
    this.onDismissAll,
  });

  final AppNotification notification;
  final VoidCallback onView;

  /// How many more are waiting behind this one.
  final int queuedBehind;

  /// Drops the rest of the queue instead of stepping through it. Null
  /// when this is the last one.
  final VoidCallback? onDismissAll;

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
        if (onDismissAll != null)
          TextButton(
            onPressed: () {
              onDismissAll!();
              Navigator.pop(context);
            },
            child: const Text('Dismiss all'),
          ),
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

/// Shown instead of a queue when several notifications land at once —
/// one acknowledgement for the batch, with the inbox one tap away.
class _NotificationSummaryModal extends StatelessWidget {
  const _NotificationSummaryModal({
    required this.count,
    required this.onView,
  });

  final int count;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 30,
                    color: scheme.primary,
                  ),
                ),
              ),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              '$count new notifications',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ).fadeUp(delay: const Duration(milliseconds: 70)),
            const SizedBox(height: 8),
            Text(
              'Open your notifications to read them.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ).fadeUp(delay: const Duration(milliseconds: 110)),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onView();
          },
          child: const Text('View all'),
        ),
      ],
    );
  }
}
