import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../core/offline/connectivity_providers.dart';
import '../../../core/theme/view_mode_controller.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../../core/widgets/sbs_table.dart';
import '../../../core/widgets/workbench_scaffold.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';
import '../data/approvals_repository.dart';
import '../data/evidence_sync_queue.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In the sidebar shell the header shows the page title, so the AppBar
    // collapses to just the tab strip and the walk-in action becomes a
    // FAB (matching Items' "Add item" / Requests' "New request"). On a
    // phone the AppBar comes back, and walk-in lives in the Manage sheet.
    final inWebShell = inStaffSidebarShell(context, ref);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: inWebShell ? 0 : null,
          title: inWebShell ? null : const Text('Approvals'),
          automaticallyImplyLeading: false,
          actions: inWebShell
              ? null
              : [
                  IconButton(
                    tooltip: 'Walk-in request',
                    icon: const Icon(Icons.person_add_alt_outlined),
                    onPressed: () => context.push(AppRoutes.walkinNew),
                  ),
                ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'To Release'),
              Tab(text: 'To Return'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: inWebShell
            ? FloatingActionButton.extended(
                onPressed: () => context.push(AppRoutes.walkinNew),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Walk-in request'),
              )
            : null,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const _SyncBanner(),
            // On a phone the toggle is dead weight — a table can't be read
            // at that width anyway, so the row it occupies is better spent
            // on the queue itself.
            if (MediaQuery.sizeOf(context).width >= 720)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ViewModeToggle(
                    width: MediaQuery.sizeOf(context).width,
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _ApprovalQueue(
                    status: 'pending',
                    emptyText: 'No pending requests in your scope. 🎉',
                    onTap: (context, req) =>
                        context.push(AppRoutes.approvalDetail, extra: req),
                  ),
                  _ApprovalQueue(
                    status: 'approved',
                    emptyText: 'Nothing awaiting release.',
                    onTap: (context, req) => context.push(
                      AppRoutes.evidenceCapture,
                      extra: EvidenceCaptureArgs(
                        request: req,
                        stage: 'release',
                      ),
                    ),
                  ),
                  _ApprovalQueue(
                    status: 'released,overdue',
                    emptyText: 'Nothing currently out on loan.',
                    onTap: (context, req) => context.push(
                      AppRoutes.evidenceCapture,
                      extra: EvidenceCaptureArgs(request: req, stage: 'return'),
                    ),
                  ),
                  _ApprovalQueue(
                    status: 'returned,closed,rejected',
                    emptyText: 'No completed or rejected requests yet.',
                    showStatusChip: true,
                    onTap: (context, req) => req.status == 'rejected'
                        ? _showRejectionReason(context, req)
                        : context.push(
                            AppRoutes.evidenceView,
                            extra: EvidenceViewArgs(
                              requestId: req.id,
                              itemLabel: req.itemLabel,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalQueue extends ConsumerWidget {
  const _ApprovalQueue({
    required this.status,
    required this.emptyText,
    required this.onTap,
    this.showStatusChip = false,
  });

  final String status;
  final String emptyText;
  final void Function(BuildContext, PendingApproval) onTap;

  /// True for the History tab, which mixes several terminal statuses
  /// together — each row needs to say which one, unlike the other tabs
  /// where the tab itself already implies the status.
  final bool showStatusChip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(approvalQueueProvider(status));
    final pref = ref.watch(viewModeProvider);
    return switch (queue) {
      AsyncData(:final value) when value.requests.isEmpty => _QueueEmptyState(
        text: emptyText,
        status: status,
        cachedAt: value.cachedAt,
      ),
      AsyncData(:final value) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mode = effectiveViewMode(pref, constraints.maxWidth);
              final rows = value.requests;
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(approvalQueueProvider(status)),
                child: Column(
                  children: [
                    if (value.cachedAt != null)
                      _StaleNotice(cachedAt: value.cachedAt!),
                    Expanded(
                      child: mode == ViewMode.table
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: SbsTable(
                                columns: const [
                                  'Item',
                                  'Qty',
                                  'Borrower',
                                  'Use',
                                  'Pickup → Return',
                                  '',
                                ],
                                rows: [
                                  for (final req in rows)
                                    SbsRow(
                                      onTap: () => onTap(context, req),
                                      cells: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              child: Icon(
                                                _borrowerIcon(req),
                                                size: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(req.itemLabel),
                                          ],
                                        ),
                                        Text(
                                          req.itemQuantity > 1
                                              ? '${req.quantityRequested} of ${req.itemQuantity}'
                                              : '—',
                                        ),
                                        Text(
                                          '${req.borrowerName}\n'
                                          '(${_borrowerTypeLabel(req)})',
                                        ),
                                        Text(
                                          req.useFrom != null &&
                                                  req.useTo != null
                                              ? '${formatDateTime(req.useFrom!)}\n'
                                                    '→ ${formatDateTime(req.useTo!)}'
                                              : '—',
                                        ),
                                        Text(
                                          '${formatDateTime(req.requestedFrom)}\n'
                                          '→ ${_dateOrOpenEnded(req.requestedTo)}',
                                        ),
                                        if (showStatusChip)
                                          RequestStatusChip(status: req.status)
                                        else if (req.isOverdue)
                                          Chip(
                                            label: const Text('OVERDUE'),
                                            visualDensity: VisualDensity.compact,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.errorContainer,
                                          )
                                        else
                                          const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: rows.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) => _ApprovalCard(
                                request: rows[index],
                                onTap: () => onTap(context, rows[index]),
                                showStatusChip: showStatusChip,
                              ).fadeUpAt(index),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      // Only reached when the fetch failed *and* nothing was cached — a
      // first run on this device, essentially.
      AsyncError() => _QueueErrorState(
        offline: !ref.watch(isOnlineProvider),
        onRetry: () => ref.invalidate(approvalQueueProvider(status)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

String _dateOrOpenEnded(DateTime? dt) =>
    dt == null ? 'not yet known' : formatDateTime(dt);

void _showRejectionReason(BuildContext context, PendingApproval req) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(req.itemLabel),
      content: Text(req.rejectedReason ?? 'No reason given.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _borrowerTypeLabel(PendingApproval req) => switch (req.borrowerType) {
  'citizen' => 'Citizen',
  'guest' => 'Walk-in',
  _ => 'Staff',
};

IconData _borrowerIcon(PendingApproval req) => req.isGuestBorrower
    ? Icons.badge_outlined
    : req.isCitizenBorrower
    ? Icons.person_outline
    : Icons.work_outline;

/// Mobile/narrow layout: the original Card+ListTile row.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    required this.onTap,
    this.showStatusChip = false,
  });

  final PendingApproval request;
  final VoidCallback onTap;
  final bool showStatusChip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_borrowerIcon(request))),
        title: Text(request.itemLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.borrowerName} (${_borrowerTypeLabel(request)})'),
            if (request.itemQuantity > 1)
              Text(
                'Quantity: ${request.quantityRequested} of ${request.itemQuantity}',
              ),
            if (request.useFrom != null && request.useTo != null)
              Text(
                'Use: ${formatDateTime(request.useFrom!)} → '
                '${formatDateTime(request.useTo!)}',
              )
            else
              Text(
                '${formatDateTime(request.requestedFrom)} → '
                '${_dateOrOpenEnded(request.requestedTo)}',
              ),
          ],
        ),
        isThreeLine: true,
        trailing: showStatusChip
            ? RequestStatusChip(status: request.status)
            : request.isOverdue
                ? Chip(
                    label: const Text('OVERDUE'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  )
                : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class ApprovalDetailScreen extends ConsumerStatefulWidget {
  const ApprovalDetailScreen({super.key, required this.request});

  final PendingApproval request;

  @override
  ConsumerState<ApprovalDetailScreen> createState() =>
      _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends ConsumerState<ApprovalDetailScreen> {
  bool _busy = false;

  PendingApproval get req => widget.request;

  Future<void> _run(Future<void> Function() action, String successMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(approvalQueueProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      if (mounted) context.pop();
    } on ReservationConflictException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot approve: overlaps an existing approved '
            'reservation for this item.',
          ),
        ),
      );
    } on CitizenNotVerifiedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Verify the citizen\'s identity first.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to the borrower)',
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _run(
      () => ref.read(approvalsRepositoryProvider).reject(req.id, reason),
      'Request rejected.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verification = req.isCitizenBorrower
        ? ref.watch(citizenVerificationProvider(req.borrowerId!))
        : null;
    final citizenVerified = verification?.value?.verified ?? false;
    final canApprove = !req.isCitizenBorrower || citizenVerified;

    return WorkbenchScaffold(
      title: 'Review Request',
      subtitle: req.itemLabel,
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkbenchCard(
            title: 'Request',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  req.itemLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                if (req.itemQuantity > 1)
                  WorkbenchField(
                    icon: Icons.pin_outlined,
                    label: 'QUANTITY',
                    value:
                        '${req.quantityRequested} of ${req.itemQuantity} units',
                  ),
                if (req.useFrom != null && req.useTo != null)
                  WorkbenchField(
                    icon: Icons.event,
                    label: 'USED FROM → TO',
                    value: '${_fmt(req.useFrom!)}  →  ${_fmt(req.useTo!)}',
                  ),
                WorkbenchField(
                  icon: Icons.local_shipping_outlined,
                  label: 'PICKUP → RETURN',
                  value:
                      '${_fmt(req.requestedFrom)}  →  '
                      '${req.requestedTo == null ? "not yet known" : _fmt(req.requestedTo!)}',
                ),
                WorkbenchField(
                  icon: Icons.notes_outlined,
                  label: 'PURPOSE',
                  value: req.purpose,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkbenchCard(
            title: 'Borrower',
            icon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(
                        _initials(req.borrowerName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.borrowerName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (req.borrowerType) {
                              'citizen' => 'Citizen',
                              'guest' => 'Walk-in guest',
                              _ => 'LGU Staff',
                            },
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (req.isCitizenBorrower) ...[
                  const SizedBox(height: 16),
                  switch (verification!) {
                    AsyncData(:final value) => _VerificationCard(
                      verification: value,
                      busy: _busy,
                      onVerify: () => _run(() async {
                        await ref
                            .read(approvalsRepositoryProvider)
                            .verifyCitizen(req.borrowerId!);
                        ref.invalidate(
                          citizenVerificationProvider(req.borrowerId!),
                        );
                      }, 'Identity verified.'),
                    ),
                    AsyncError() => const Text(
                      'Could not load verification data.',
                    ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ],
              ],
            ),
          ),
        ],
      ),
      side: WorkbenchCard(
        title: 'Decision',
        icon: Icons.gavel_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spelling out why Approve is locked, next to the button
            // itself — previously this was only implied by the label.
            if (!canApprove)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07A1F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.gpp_maybe_outlined,
                      size: 17,
                      color: Color(0xFFE07A1F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verify this citizen\'s ID above before approving.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: _busy || !canApprove
                  ? null
                  : () => _run(
                      () => ref
                          .read(approvalsRepositoryProvider)
                          .approve(req.id),
                      'Request approved.',
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F9D65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 19),
              label: const Text('Approve request'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              icon: const Icon(Icons.close, size: 19),
              label: const Text('Reject…'),
            ),
            const SizedBox(height: 14),
            Text(
              'Approving reserves the item for this window. The borrower is '
              'notified either way.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) => formatDateTime(dt);

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}


/// "Nothing here" for an approvals tab. Each tab means something
/// different when empty — an empty Pending queue is good news, an empty
/// History just means nothing has completed yet — so the icon follows
/// the status rather than being one generic glyph.
class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({
    required this.text,
    required this.status,
    this.cachedAt,
  });

  final String text;
  final String status;

  /// Set when even this "nothing here" is a cached answer — an empty
  /// queue you can't trust is not the same news as an empty queue you can.
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tint) = switch (status) {
      'pending' => (Icons.task_alt, const Color(0xFF1F9D65)),
      'approved' => (Icons.outbox_outlined, scheme.primary),
      'released,overdue' => (Icons.inventory_2_outlined, scheme.primary),
      _ => (Icons.history_toggle_off, scheme.onSurfaceVariant),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 33, color: tint),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ).fadeUp(delay: const Duration(milliseconds: 80)),
            if (cachedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Offline — last checked ${formatRelative(cachedAt!)}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ).fadeUp(delay: const Duration(milliseconds: 120)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The queue could not be loaded and there was no cached copy to fall
/// back on. Distinguishes "you're offline" from "something broke",
/// because only one of those is worth retrying on the spot.
class _QueueErrorState extends StatelessWidget {
  const _QueueErrorState({required this.offline, required this.onRetry});

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.error_outline,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              offline
                  ? 'You\'re offline and this queue hasn\'t been loaded on '
                        'this device yet.'
                  : 'Could not load requests.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strip above a queue that's being served from the offline cache.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE07A1F);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 17, color: amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline — showing the queue as of ${formatRelative(cachedAt)}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits above the approvals tabs whenever captures are waiting to reach
/// the server. Tapping it opens the list, so a capture can never go
/// missing without the approver being able to see exactly what's stuck.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref.watch(evidenceSyncQueueProvider);
    if (queued.isEmpty) return const SizedBox.shrink();

    final blocked = queued.where((e) => e.isBlocked).length;
    final scheme = Theme.of(context).colorScheme;
    final tint = blocked > 0 ? scheme.error : const Color(0xFF2B7FFF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPendingSyncSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  blocked > 0 ? Icons.error_outline : Icons.cloud_upload_outlined,
                  size: 18,
                  color: tint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    blocked > 0
                        ? '$blocked capture${blocked == 1 ? "" : "s"} could not '
                              'be sent — tap to review'
                        : '${queued.length} capture'
                              '${queued.length == 1 ? "" : "s"} waiting to sync',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showPendingSyncSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _PendingSyncSheet(),
  );
}

class _PendingSyncSheet extends ConsumerWidget {
  const _PendingSyncSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref.watch(evidenceSyncQueueProvider);
    final notifier = ref.read(evidenceSyncQueueProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Waiting to sync',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'These handoffs are recorded on this phone and will be sent '
                'automatically once there is a connection.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            if (queued.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Text('Everything is synced. 🎉'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: queued.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final entry = queued[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(
                          entry.isRelease
                              ? Icons.outbound
                              : Icons.assignment_turned_in,
                          color: entry.isBlocked ? scheme.error : null,
                        ),
                        title: Text(entry.itemLabel),
                        subtitle: Text(
                          entry.isBlocked
                              ? 'Rejected: ${entry.lastError}'
                              : '${entry.isRelease ? "Release" : "Return"} • '
                                    '${entry.photoPaths.length} photo'
                                    '${entry.photoPaths.length == 1 ? "" : "s"} • '
                                    '${formatRelative(entry.queuedAt)}',
                        ),
                        isThreeLine: entry.isBlocked,
                        trailing: entry.isBlocked
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Retry',
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () => notifier.retry(entry.id),
                                  ),
                                  IconButton(
                                    tooltip: 'Discard',
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: scheme.error,
                                    ),
                                    onPressed: () => notifier.discard(entry.id),
                                  ),
                                ],
                              )
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.verification,
    required this.busy,
    required this.onVerify,
  });

  final CitizenVerification verification;
  final bool busy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: verification.verified
          ? scheme.secondaryContainer
          : scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  verification.verified ? Icons.verified_user : Icons.gpp_maybe,
                ),
                const SizedBox(width: 8),
                Text(
                  verification.verified
                      ? 'Identity verified'
                      : 'First-time borrower — verify identity',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${verification.idType} • ${verification.idNumber}'),
            Text('Contact: ${verification.contactNumber}'),
            if (verification.idPhotoUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  verification.idPhotoUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, e, s) =>
                      const Text('Could not load ID photo.'),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No ID photo on file.'),
              ),
            if (!verification.verified) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: busy ? null : onVerify,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Mark identity as verified'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
