import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/borrow_models.dart';
import '../data/borrow_providers.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.requestNew),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: switch (requests) {
        AsyncData(:final value) when value.isEmpty => const Center(
            child: Text('No requests yet — tap "New request" to start.'),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRequestsProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: value.length,
              itemBuilder: (context, index) =>
                  _RequestTile(request: value[index]),
            ),
          ),
        AsyncError() => const Center(child: Text('Could not load requests.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
