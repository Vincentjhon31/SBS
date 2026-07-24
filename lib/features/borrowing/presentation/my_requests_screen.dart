import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../approvals/data/approvals_models.dart';
import '../../items/data/items_providers.dart';
import '../data/borrow_models.dart';
import '../data/borrow_providers.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    final active = ref.watch(activeRequestsProvider);
    final history = ref.watch(historyRequestsProvider);
    // On the staff website the shell header shows the page title — keep
    // only the tab strip. Citizens (mobile/web) keep the full AppBar.
    final inWebShell = kIsWeb && ref.watch(isStaffProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: inWebShell ? 0 : null,
          title: inWebShell ? null : const Text('My Requests'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.requestNew),
          icon: const Icon(Icons.add),
          label: const Text('New request'),
        ),
        body: switch (requests) {
          AsyncData() => TabBarView(
            children: [
              _RequestsList(
                requests: active,
                emptyText: 'No active requests — tap "New request" to start.',
                onRefresh: () async => ref.invalidate(myRequestsProvider),
              ),
              _RequestsList(
                requests: history,
                emptyText: 'No past requests yet.',
                onRefresh: () async => ref.invalidate(myRequestsProvider),
              ),
            ],
          ),
          AsyncError() => const Center(child: Text('Could not load requests.')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 380).floor().clamp(1, 3);
            if (columns == 1) {
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
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 88),
                // _RequestTile's own Card margin supplies the gutters, so
                // the grid itself adds no extra spacing (avoids doubling up).
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 1.5,
                ),
                itemCount: requests.length,
                itemBuilder: (context, index) =>
                    _RequestTile(request: requests[index]),
              ),
            );
          },
        ),
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
            ? () => context.push(
                AppRoutes.evidenceView,
                extra: EvidenceViewArgs(
                  requestId: request.id,
                  itemLabel: request.itemLabel,
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
                  RequestStatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_date(request.requestedFrom)} → ${_date(request.requestedTo)}',
              ),
              if (request.dueAt != null &&
                  const {
                    'approved',
                    'released',
                    'overdue',
                  }.contains(request.status)) ...[
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
