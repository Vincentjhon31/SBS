import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/sbs_nav_bar.dart';
import '../../approvals/data/approvals_models.dart';
import '../data/borrow_models.dart';
import '../data/borrow_providers.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  static const _activeStatuses = {'pending', 'approved', 'released', 'overdue'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Requests'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(tabs: [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ]),
        ),
        bottomNavigationBar: const SBSNavBar(current: AppRoutes.requests),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go(AppRoutes.requestNew),
          icon: const Icon(Icons.add),
          label: const Text('New request'),
        ),
        body: switch (requests) {
          AsyncData(:final value) => TabBarView(
            children: [
              _RequestsList(
                requests: _sortActive([
                  for (final r in value)
                    if (_activeStatuses.contains(r.status)) r,
                ]),
                emptyText: 'No active requests — tap "New request" to start.',
                onRefresh: () async => ref.invalidate(myRequestsProvider),
              ),
              _RequestsList(
                requests: [
                  for (final r in value)
                    if (!_activeStatuses.contains(r.status)) r,
                ],
                emptyText: 'No past requests yet.',
                onRefresh: () async => ref.invalidate(myRequestsProvider),
              ),
            ],
          ),
          AsyncError() =>
            const Center(child: Text('Could not load requests.')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// Soonest obligation first: due date when set, otherwise start date.
  static List<BorrowRequest> _sortActive(List<BorrowRequest> list) {
    list.sort((a, b) => (a.dueAt ?? a.requestedFrom)
        .compareTo(b.dueAt ?? b.requestedFrom));
    return list;
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.emptyText,
    required this.onRefresh,
  });

  final List<BorrowRequest> requests;
  final String emptyText;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: requests.length,
        itemBuilder: (context, index) =>
            _RequestTile(request: requests[index]),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final BorrowRequest request;

  static const _evidenceStatuses = {
    'released',
    'returned',
    'closed',
    'overdue',
  };

  @override
  Widget build(BuildContext context) {
    final hasEvidence = _evidenceStatuses.contains(request.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: hasEvidence
            ? () => context.go(
                AppRoutes.evidenceView,
                extra: EvidenceViewArgs(
                  requestId: request.id,
                  itemLabel: request.itemLabel,
                  backRoute: AppRoutes.requests,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.itemLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_date(request.requestedFrom)} → ${_date(request.requestedTo)}',
              ),
              if (request.dueAt != null &&
                  const {'approved', 'released', 'overdue'}
                      .contains(request.status)) ...[
                const SizedBox(height: 2),
                Text(
                  'Due back ${_date(request.dueAt!)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: request.status == 'overdue'
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                request.purpose,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (request.status == 'rejected' &&
                  request.rejectedReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Reason: ${request.rejectedReason}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      'pending' => (scheme.tertiaryContainer, 'Pending'),
      'approved' => (scheme.primaryContainer, 'Approved'),
      'rejected' => (scheme.errorContainer, 'Rejected'),
      'released' => (scheme.secondaryContainer, 'Released'),
      'returned' => (scheme.surfaceContainerHighest, 'Returned'),
      'closed' => (scheme.surfaceContainerHighest, 'Closed'),
      'overdue' => (scheme.errorContainer, 'OVERDUE'),
      _ => (scheme.surfaceContainerHighest, status),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
