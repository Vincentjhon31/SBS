import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/sbs_nav_bar.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';
import '../data/approvals_repository.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const SBSNavBar(current: AppRoutes.approvals),
      body: switch (pending) {
        AsyncData(:final value) when value.isEmpty => const Center(
            child: Text('No pending requests in your scope. 🎉'),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingApprovalsProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: value.length,
              itemBuilder: (context, index) {
                final req = value[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(req.isCitizenBorrower
                          ? Icons.person_outline
                          : Icons.badge_outlined),
                    ),
                    title: Text(req.itemLabel),
                    subtitle: Text(
                      '${req.borrowerName} '
                      '(${req.isCitizenBorrower ? "Citizen" : "Staff"})\n'
                      '${_date(req.requestedFrom)} → ${_date(req.requestedTo)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.go(AppRoutes.approvalDetail, extra: req),
                  ),
                );
              },
            ),
          ),
        AsyncError() => const Center(child: Text('Could not load approvals.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
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
      ref.invalidate(pendingApprovalsProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      if (mounted) context.go(AppRoutes.approvals);
    } on ReservationConflictException {
      messenger.showSnackBar(const SnackBar(
        content: Text('Cannot approve: overlaps an existing approved '
            'reservation for this item.'),
      ));
    } on CitizenNotVerifiedException {
      messenger.showSnackBar(const SnackBar(
        content: Text('Verify the citizen\'s identity first.'),
      ));
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
        ? ref.watch(citizenVerificationProvider(req.borrowerId))
        : null;
    final citizenVerified = verification?.value?.verified ?? false;
    final canApprove = !req.isCitizenBorrower || citizenVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Request'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.approvals)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(req.itemLabel,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${_fmt(req.requestedFrom)}  →  ${_fmt(req.requestedTo)}'),
              const SizedBox(height: 16),
              Text('Purpose', style: Theme.of(context).textTheme.labelLarge),
              Text(req.purpose),
              const Divider(height: 32),
              Text('Borrower', style: Theme.of(context).textTheme.labelLarge),
              Text('${req.borrowerName} '
                  '(${req.isCitizenBorrower ? "Citizen" : "LGU Staff"})'),
              if (req.isCitizenBorrower) ...[
                const SizedBox(height: 12),
                switch (verification!) {
                  AsyncData(:final value) => _VerificationCard(
                      verification: value,
                      busy: _busy,
                      onVerify: () => _run(
                        () async {
                          await ref
                              .read(approvalsRepositoryProvider)
                              .verifyCitizen(req.borrowerId);
                          ref.invalidate(
                              citizenVerificationProvider(req.borrowerId));
                        },
                        'Identity verified.',
                      ),
                    ),
                  AsyncError() =>
                    const Text('Could not load verification data.'),
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
                label: Text(canApprove
                    ? 'Approve'
                    : 'Approve (verify identity first)'),
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
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
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
                Icon(verification.verified
                    ? Icons.verified_user
                    : Icons.gpp_maybe),
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
