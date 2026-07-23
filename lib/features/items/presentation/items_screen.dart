import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/item_status_chip.dart';
import '../data/items_models.dart';
import '../data/items_providers.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String _query = '';

  /// null = "All" — no forced taxonomy, so options are whatever staff have
  /// actually typed into the free-text category field.
  String? _category;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final statuses = ref.watch(itemStatusesProvider).value ?? {};
    final isStaff = ref.watch(isStaffProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Items Registry'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.itemNew),
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
          switch (items) {
            AsyncData(:final value) => _CategoryChips(
              categories: _categories(value),
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
            _ => const SizedBox.shrink(),
          },
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
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
                      child: Text(
                        'Could not load items.\n$error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _categories(List<Item> all) {
    final set = {
      for (final item in all)
        if (item.category != null && item.category!.trim().isNotEmpty)
          item.category!,
    };
    final list = set.toList()..sort();
    return list;
  }

  List<Item> _filtered(List<Item> all) {
    return [
      for (final item in all)
        if ((_category == null || item.category == _category) &&
            (_query.isEmpty ||
                item.name.toLowerCase().contains(_query) ||
                (item.distinguishingTag?.toLowerCase().contains(_query) ??
                    false) ||
                (item.category?.toLowerCase().contains(_query) ?? false)))
          item,
    ];
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (context, index) => _ItemRow(
                item: items[index],
                status: statuses[items[index].id],
                isStaff: isStaff,
              ),
            ),
          );
        }
        final columns = (constraints.maxWidth / 280).floor().clamp(3, 5);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 88),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _ItemCard(
              item: items[index],
              status: statuses[items[index].id],
              isStaff: isStaff,
            ),
          ),
        );
      },
    );
  }
}

/// Mobile/narrow layout: one item per row, matching the original list.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.status,
    required this.isStaff,
  });

  final Item item;
  final ItemStatus? status;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
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
          if (status != null) _statusCaption(context, status!),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!item.active)
            Chip(
              label: const Text('Inactive'),
              visualDensity: VisualDensity.compact,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            )
          else if (status != null)
            ItemStatusChip(status: status!.status),
          IconButton(
            tooltip: 'Reservation calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(AppRoutes.itemCalendar, extra: item),
          ),
        ],
      ),
      onTap: isStaff
          ? () => context.push(AppRoutes.itemEdit, extra: item)
          : null,
    );
  }
}

/// Desktop/wide layout: a card grid, closer to a typical admin registry
/// than a phone-style list — more items visible at once, still tappable
/// for staff to edit.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.status,
    required this.isStaff,
  });

  final Item item;
  final ItemStatus? status;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isStaff
            ? () => context.push(AppRoutes.itemEdit, extra: item)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ItemThumbnail(path: item.referencePhotoPath, radius: 22),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Reservation calendar',
                    icon: const Icon(Icons.calendar_month_outlined),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        context.push(AppRoutes.itemCalendar, extra: item),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.displayName,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (item.category != null) item.category!,
                  item.departmentName ?? 'Shared LGU pool',
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (status != null) _statusCaption(context, status!),
              const Spacer(),
              if (!item.active)
                Chip(
                  label: const Text('Inactive'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                )
              else if (status != null)
                ItemStatusChip(status: status!.status),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _statusCaption(BuildContext context, ItemStatus status) {
  final String? text;
  if ((status.status == 'out' || status.status == 'overdue') &&
      status.currentDue != null) {
    text = 'Due back ${_date(status.currentDue!)}';
  } else if (status.status == 'available' && status.nextReservedFrom != null) {
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

String _date(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

class _ItemThumbnail extends ConsumerWidget {
  const _ItemThumbnail({this.path, this.radius});

  final String? path;
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) {
      return CircleAvatar(
        radius: radius,
        child: const Icon(Icons.inventory_2_outlined),
      );
    }
    final url = ref.watch(itemPhotoUrlProvider(path!));
    return switch (url) {
      AsyncData(:final value) => CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(value),
        onBackgroundImageError: (_, s) {},
      ),
      _ => CircleAvatar(
        radius: radius,
        child: const Icon(Icons.image_outlined),
      ),
    };
  }
}
