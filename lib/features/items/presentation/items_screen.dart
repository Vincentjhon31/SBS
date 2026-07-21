import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/sbs_nav_bar.dart';
import '../data/items_models.dart';
import '../data/items_providers.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final statuses = ref.watch(itemStatusesProvider).value ?? {};
    final isStaff = ref.watch(isStaffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items Registry'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const SBSNavBar(current: AppRoutes.items),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.itemNew),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items…',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: switch (items) {
              AsyncData(:final value) => _ItemsList(
                  items: _filtered(value),
                  statuses: statuses,
                  isStaff: isStaff,
                  onRefresh: () async {
                    ref.invalidate(itemsProvider);
                    ref.invalidate(itemStatusesProvider);
                  },
                ),
              AsyncError(:final error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load items.\n$error',
                        textAlign: TextAlign.center),
                  ),
                ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  List<Item> _filtered(List<Item> all) {
    if (_query.isEmpty) return all;
    return [
      for (final item in all)
        if (item.name.toLowerCase().contains(_query) ||
            (item.distinguishingTag?.toLowerCase().contains(_query) ?? false) ||
            (item.category?.toLowerCase().contains(_query) ?? false))
          item,
    ];
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.items,
    required this.statuses,
    required this.isStaff,
    required this.onRefresh,
  });

  final List<Item> items;
  final Map<String, ItemStatus> statuses;
  final bool isStaff;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found.'));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final status = statuses[item.id];
          return ListTile(
            leading: _ItemThumbnail(path: item.referencePhotoPath),
            title: Text(item.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (item.category != null) item.category!,
                    item.departmentName ?? 'Shared LGU pool',
                  ].join(' • '),
                ),
                if (status != null) _statusCaption(context, status),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.active)
                  Chip(
                    label: const Text('Inactive'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  )
                else if (status != null)
                  _StatusChip(status: status.status),
                IconButton(
                  tooltip: 'Reservation calendar',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () =>
                      context.go(AppRoutes.itemCalendar, extra: item),
                ),
              ],
            ),
            onTap: isStaff
                ? () => context.go(AppRoutes.itemEdit, extra: item)
                : null,
          );
        },
      ),
    );
  }

  Widget _statusCaption(BuildContext context, ItemStatus status) {
    final String? text;
    if ((status.status == 'out' || status.status == 'overdue') &&
        status.currentDue != null) {
      text = 'Due back ${_date(status.currentDue!)}';
    } else if (status.status == 'available' &&
        status.nextReservedFrom != null) {
      text = 'Next reservation ${_date(status.nextReservedFrom!)}';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: status.status == 'overdue'
                ? Theme.of(context).colorScheme.error
                : null,
          ),
    );
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      'available' => (scheme.secondaryContainer, 'Available'),
      'reserved_now' => (scheme.tertiaryContainer, 'Reserved'),
      'out' => (scheme.primaryContainer, 'On loan'),
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

class _ItemThumbnail extends ConsumerWidget {
  const _ItemThumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) {
      return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
    }
    final url = ref.watch(itemPhotoUrlProvider(path!));
    return switch (url) {
      AsyncData(:final value) => CircleAvatar(
          backgroundImage: NetworkImage(value),
          onBackgroundImageError: (_, s) {},
        ),
      _ => const CircleAvatar(child: Icon(Icons.image_outlined)),
    };
  }
}
