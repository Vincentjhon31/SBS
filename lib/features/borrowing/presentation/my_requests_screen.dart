import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/view_mode_controller.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../../core/widgets/sbs_table.dart';
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
          AsyncData() => Column(
            children: [
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
                    _RequestsList(
                      requests: active,
                      emptyText:
                          'No active requests — tap "New request" to start.',
                      onRefresh: () async => ref.invalidate(myRequestsProvider),
                    ),
                    _RequestsList(
                      requests: history,
                      emptyText: 'No past requests yet.',
                      onRefresh: () async => ref.invalidate(myRequestsProvider),
                    ),
                  ],
                ),
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

class _RequestsList extends ConsumerWidget {
  const _RequestsList({
    required this.requests,
    required this.emptyText,
    required this.onRefresh,
  });

  final List<BorrowRequest> requests;
  final String emptyText;
  final Future<void> Function() onRefresh;

  static const _evidenceStatuses = {
    'released',
    'returned',
    'closed',
    'overdue',
  };

  void _openEvidence(BuildContext context, BorrowRequest r) {
    if (!_evidenceStatuses.contains(r.status)) return;
    context.push(
      AppRoutes.evidenceView,
      extra: EvidenceViewArgs(requestId: r.id, itemLabel: r.itemLabel),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return _RequestsEmptyState(text: emptyText);
    }
    final pref = ref.watch(viewModeProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mode = effectiveViewMode(pref, constraints.maxWidth);
            if (mode == ViewMode.table) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  child: SbsTable(
                    columns: const ['Item', 'Use', 'Pickup → Return', 'Status'],
                    rows: [
                      for (final r in requests)
                        SbsRow(
                          onTap: _evidenceStatuses.contains(r.status)
                              ? () => _openEvidence(context, r)
                              : null,
                          cells: [
                            Text(r.itemLabel),
                            Text(
                              r.useFrom != null && r.useTo != null
                                  ? '${formatDateTime(r.useFrom!)}\n'
                                        '→ ${formatDateTime(r.useTo!)}'
                                  : '—',
                            ),
                            Text(
                              '${formatDateTime(r.requestedFrom)}\n'
                              '→ ${formatDateTime(r.requestedTo)}',
                            ),
                            RequestStatusChip(status: r.status),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }
            final columns = (constraints.maxWidth / 380).floor().clamp(1, 3);
            if (columns == 1) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: requests.length,
                  itemBuilder: (context, index) =>
                      _RequestTile(request: requests[index]).fadeUpAt(index),
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
                    _RequestTile(request: requests[index]).fadeUpAt(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when a tab has nothing in it — an illustration-ish icon plus a
/// route out, rather than a bare line of centred text.
class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState({required this.text});

  final String text;

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: scheme.onSurfaceVariant,
              ),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ).fadeUp(delay: const Duration(milliseconds: 80)),
            const SizedBox(height: 6),
            Text(
              'Browse the registry and send a request — it will appear here '
              'while staff review it.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ).fadeUp(delay: const Duration(milliseconds: 130)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.items),
              // Size.zero clears the theme's full-width minimum; the
              // explicit padding puts a comfortable tap target back.
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Browse items'),
            ).fadeUp(delay: const Duration(milliseconds: 180)),
          ],
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
              if (request.useFrom != null && request.useTo != null) ...[
                Text(
                  'Use: ${_date(request.useFrom!)} → ${_date(request.useTo!)}',
                ),
                const SizedBox(height: 2),
                Text(
                  'Pickup ${_date(request.requestedFrom)} · '
                  'Return ${_date(request.requestedTo)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                Text(
                  '${_date(request.requestedFrom)} → '
                  '${_date(request.requestedTo)}',
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

  static String _date(DateTime dt) => formatDateTime(dt);
}
