import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/view_mode_controller.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../../core/widgets/sbs_table.dart';
import '../../items/data/items_providers.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';
import '../data/approvals_repository.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On the staff website the shell header shows the page title, so the
    // AppBar collapses to just the tab strip and the walk-in action
    // becomes a FAB (matching Items' "Add item" / Requests' "New request").
    final inWebShell = kIsWeb && ref.watch(isStaffProvider);

    return DefaultTabController(
      length: 3,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ViewModeToggle(width: MediaQuery.sizeOf(context).width),
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
                      extra: EvidenceCaptureArgs(request: req, stage: 'release'),
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
  });

  final String status;
  final String emptyText;
  final void Function(BuildContext, PendingApproval) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(approvalQueueProvider(status));
    final pref = ref.watch(viewModeProvider);
    return switch (queue) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Text(emptyText),
      ),
      AsyncData(:final value) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mode = effectiveViewMode(pref, constraints.maxWidth);
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(approvalQueueProvider(status)),
                child: mode == ViewMode.table
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: SbsTable(
                          columns: const ['Item', 'Borrower', 'Window', ''],
                          rows: [
                            for (final req in value)
                              SbsRow(
                                onTap: () => onTap(context, req),
                                cells: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        child: Icon(_borrowerIcon(req), size: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(req.itemLabel),
                                    ],
                                  ),
                                  Text(
                                    '${req.borrowerName}\n'
                                    '(${_borrowerTypeLabel(req)})',
                                  ),
                                  Text(
                                    '${formatDateTime(req.requestedFrom)}\n'
                                    '→ ${_dateOrOpenEnded(req.requestedTo)}',
                                  ),
                                  req.isOverdue
                                      ? Chip(
                                          label: const Text('OVERDUE'),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .errorContainer,
                                        )
                                      : const Icon(Icons.chevron_right),
                                ],
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: value.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) => _ApprovalCard(
                          request: value[index],
                          onTap: () => onTap(context, value[index]),
                        ),
                      ),
              );
            },
          ),
        ),
      ),
      AsyncError() => const Center(child: Text('Could not load requests.')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

String _dateOrOpenEnded(DateTime? dt) =>
    dt == null ? 'not yet known' : formatDateTime(dt);

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
  const _ApprovalCard({required this.request, required this.onTap});

  final PendingApproval request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_borrowerIcon(request))),
        title: Text(request.itemLabel),
        subtitle: Text(
          '${request.borrowerName} (${_borrowerTypeLabel(request)})\n'
          '${formatDateTime(request.requestedFrom)} → ${_dateOrOpenEnded(request.requestedTo)}',
        ),
        isThreeLine: true,
        trailing: request.isOverdue
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
    final verification = req.isCitizenBorrower
        ? ref.watch(citizenVerificationProvider(req.borrowerId!))
        : null;
    final citizenVerified = verification?.value?.verified ?? false;
    final canApprove = !req.isCitizenBorrower || citizenVerified;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Review Request')),
      body: GlossyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      req.itemLabel,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmt(req.requestedFrom)}  →  '
                      '${req.requestedTo == null ? "not yet known" : _fmt(req.requestedTo!)}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Purpose',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(req.purpose),
                    const Divider(height: 32),
                    Text(
                      'Borrower',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${req.borrowerName} (${switch (req.borrowerType) {
                        'citizen' => 'Citizen',
                        'guest' => 'Walk-in guest',
                        _ => 'LGU Staff',
                      }})',
                    ),
                    if (req.isCitizenBorrower) ...[
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _busy || !canApprove
                          ? null
                          : () => _run(
                              () => ref
                                  .read(approvalsRepositoryProvider)
                                  .approve(req.id),
                              'Request approved.',
                            ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        canApprove
                            ? 'Approve'
                            : 'Approve (verify identity first)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject…'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) => formatDateTime(dt);
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
