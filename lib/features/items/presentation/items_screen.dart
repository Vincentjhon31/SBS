import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/theme/view_mode_controller.dart';
import '../../../core/utils/category_color.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/full_image_viewer.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../../core/widgets/item_status_chip.dart';
import '../../../core/widgets/sbs_table.dart';
import '../data/items_models.dart';
import '../data/items_providers.dart';
import '../data/items_repository.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key, this.flowFilter});

  /// When set, this is a dedicated Borrow/Schedule browsing screen (pushed
  /// from the chooser modal) instead of the unified registry tab — the
  /// item list is pre-scoped to this flow and a back button is shown.
  final ItemFlowType? flowFilter;

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  /// Mirrors [itemsQueryProvider] — shared state, so the staff web
  /// header's global search box can prefill it from anywhere.
  final _searchController = TextEditingController();

  /// null = "All" — no forced taxonomy, so options are whatever staff have
  /// actually typed into the free-text category field.
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final statuses = ref.watch(itemStatusesProvider).value ?? {};
    final isStaff = ref.watch(isStaffProvider);
    final query = ref.watch(itemsQueryProvider);
    if (_searchController.text != query) {
      _searchController.text = query;
    }
    // The staff website's shell header already shows the page title.
    final inWebShell = kIsWeb && isStaff;
    final title = switch (widget.flowFilter) {
      ItemFlowType.borrow => 'Borrow Items',
      ItemFlowType.schedule => 'Schedule Items',
      null => 'Items Registry',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: inWebShell
          ? null
          : AppBar(
              title: Text(title),
              automaticallyImplyLeading: widget.flowFilter != null,
            ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.itemNew),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      // Reached as the "Items" tab, this lives inside the shell's own
      // GlossyBackground already — but the Borrow/Schedule browsing
      // screens are pushed on top of the shell (not nested in it), so
      // they need to paint their own backdrop or the shell's shows
      // through as plain black.
      body: widget.flowFilter != null
          ? GlossyBackground(child: _buildBody(items, statuses, isStaff))
          : _buildBody(items, statuses, isStaff),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Item>> items,
    Map<String, ItemStatus> statuses,
    bool isStaff,
  ) {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search items…',
                    ),
                    onChanged: (v) =>
                        ref.read(itemsQueryProvider.notifier).set(v),
                  ),
                ),
                const SizedBox(width: 8),
                ViewModeToggle(width: MediaQuery.sizeOf(context).width),
                if (isStaff) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Manage departments',
                    icon: const Icon(Icons.apartment_outlined),
                    onPressed: () => context.push(AppRoutes.departments),
                  ),
                ],
              ],
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
            child: Align(
              alignment: Alignment.topCenter,
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
      );
  }

  List<Item> _flowScoped(List<Item> all) => [
    for (final item in all)
      if (widget.flowFilter == null || item.flowType == widget.flowFilter)
        item,
  ];

  List<String> _categories(List<Item> all) {
    final set = {
      for (final item in _flowScoped(all))
        if (item.category != null && item.category!.trim().isNotEmpty)
          item.category!,
    };
    final list = set.toList()..sort();
    return list;
  }

  List<Item> _filtered(List<Item> all) {
    final query = ref.read(itemsQueryProvider).trim().toLowerCase();
    return [
      for (final item in _flowScoped(all))
        if ((_category == null || item.category == _category) &&
            (query.isEmpty ||
                item.name.toLowerCase().contains(query) ||
                (item.distinguishingTag?.toLowerCase().contains(query) ??
                    false) ||
                (item.category?.toLowerCase().contains(query) ?? false)))
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
              child: Builder(
                builder: (context) {
                  final (bg, fg) = categoryColor(category);
                  final isSelected = selected == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => onSelected(category),
                    labelStyle: TextStyle(
                      color: fg,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: bg.withValues(alpha: 0.55),
                    selectedColor: bg,
                    side: BorderSide.none,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemsList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found.'));
    }
    final pref = ref.watch(viewModeProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = effectiveViewMode(pref, constraints.maxWidth);
        if (mode == ViewMode.table) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: _ItemTable(
              items: items,
              statuses: statuses,
              isStaff: isStaff,
            ),
          );
        }
        // Cards: a grid on wide screens, a single-column list on phones.
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
              // Shorter than square — the card now leads with a wide photo
              // banner (16:10) on top of the usual details underneath.
              childAspectRatio: 0.78,
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

/// Table view — one item per row, columns for the details staff scan for.
class _ItemTable extends StatelessWidget {
  const _ItemTable({
    required this.items,
    required this.statuses,
    required this.isStaff,
  });

  final List<Item> items;
  final Map<String, ItemStatus> statuses;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return SbsTable(
      columns: const ['Item', 'Category', 'Department', 'Status', ''],
      rows: [
        for (final item in items)
          SbsRow(
            onTap: isStaff
                ? () => context.push(AppRoutes.itemEdit, extra: item)
                : () => context.push(AppRoutes.requestNew, extra: item),
            cells: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ItemThumbnail(
                    path: item.referencePhotoPath,
                    size: 40,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      item.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isStaff && item.needsReview) ...[
                    const SizedBox(width: 6),
                    const _NeedsReviewBadge(),
                  ],
                ],
              ),
              item.category != null && item.category!.trim().isNotEmpty
                  ? CategoryBadge(category: item.category)
                  : const Text('—'),
              Text(item.departmentName ?? 'Shared LGU pool'),
              _StatusCell(item: item, status: statuses[item.id]),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Reservation calendar',
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () =>
                        context.push(AppRoutes.itemCalendar, extra: item),
                  ),
                  if (isStaff) _DeleteItemButton(item: item),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.item, required this.status});

  final Item item;
  final ItemStatus? status;

  @override
  Widget build(BuildContext context) {
    if (!item.active) {
      return Chip(
        label: const Text('Inactive'),
        visualDensity: VisualDensity.compact,
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      );
    }
    if (status == null) return const Text('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ItemStatusChip(status: status!.status, quantity: status!.quantity, availableCount: status!.availableCount),
        _statusCaption(context, status!),
      ],
    );
  }
}

/// Mobile/narrow layout: one item per row, matching the original list — a
/// large photo (not a tiny avatar) so the item is actually recognizable at
/// a glance, matching the Home hero cards' treatment.
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isStaff
            ? () => context.push(AppRoutes.itemEdit, extra: item)
            : () => context.push(AppRoutes.requestNew, extra: item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemThumbnail(
                path: item.referencePhotoPath,
                size: 84,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isStaff && item.needsReview)
                          const _NeedsReviewBadge(),
                        if (item.category != null &&
                            item.category!.trim().isNotEmpty)
                          CategoryBadge(category: item.category),
                        Text(item.departmentName ?? 'Shared LGU pool'),
                      ],
                    ),
                    if (status != null) _statusCaption(context, status!),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (!item.active)
                          Chip(
                            label: const Text('Inactive'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                          )
                        else if (status != null)
                          ItemStatusChip(status: status!.status, quantity: status!.quantity, availableCount: status!.availableCount),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Reservation calendar',
                          icon: const Icon(Icons.calendar_month_outlined),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => context.push(
                            AppRoutes.itemCalendar,
                            extra: item,
                          ),
                        ),
                        if (isStaff)
                          _DeleteItemButton(
                            item: item,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            : () => context.push(AppRoutes.requestNew, extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A real photo banner up top (Home hero-card treatment) instead
            // of a tiny avatar buried in the action row.
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _ItemThumbnail(
                path: item.referencePhotoPath,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isStaff && item.needsReview) ...[
                        const _NeedsReviewBadge(),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        tooltip: 'Reservation calendar',
                        icon: const Icon(Icons.calendar_month_outlined),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            context.push(AppRoutes.itemCalendar, extra: item),
                      ),
                      if (isStaff)
                        _DeleteItemButton(
                          item: item,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  _ItemCardBody(item: item, status: status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCardBody extends StatelessWidget {
  const _ItemCardBody({required this.item, required this.status});

  final Item item;
  final ItemStatus? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            if (item.category != null && item.category!.trim().isNotEmpty)
              CategoryBadge(category: item.category),
            Text(
              item.departmentName ?? 'Shared LGU pool',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        if (status != null) _statusCaption(context, status!),
        const SizedBox(height: 4),
        if (!item.active)
          Chip(
            label: const Text('Inactive'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          )
        else if (status != null)
          ItemStatusChip(status: status!.status, quantity: status!.quantity, availableCount: status!.availableCount),
      ],
    );
  }
}

/// Staff-only marker for a citizen-typed item that hasn't been reviewed
/// yet (category/department/photo) — clears automatically once staff edit
/// the item.
class _NeedsReviewBadge extends StatelessWidget {
  const _NeedsReviewBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Added by a citizen request — needs a look',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'New',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.amber.shade900,
            fontWeight: FontWeight.w700,
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
    text = 'Due back ${formatDate(status.currentDue!)}';
  } else if (status.status == 'available' && status.nextReservedFrom != null) {
    text = 'Next reservation ${formatDate(status.nextReservedFrom!)}';
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

/// A real, recognizable rounded-rect photo (the Home hero cards'
/// treatment) rather than a tiny circular avatar — tap to view full-screen.
/// Pass [size] for a fixed square thumbnail (list/table rows), or leave it
/// null to fill whatever bounded parent it's given (e.g. an [AspectRatio]
/// banner).
class _ItemThumbnail extends ConsumerWidget {
  const _ItemThumbnail({
    this.path,
    this.size,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final double? size;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
    if (path == null) return placeholder(Icons.inventory_2_outlined);

    final url = ref.watch(itemPhotoUrlProvider(path!));
    return switch (url) {
      AsyncData(:final value) => Tooltip(
        message: 'View photo',
        child: GestureDetector(
          onTap: () => showFullImage(context, value),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.network(
                value,
                fit: fit,
                errorBuilder: (context, e, s) =>
                    placeholder(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
      _ => placeholder(Icons.image_outlined),
    };
  }
}

/// A destructive delete affordance for the registry. Permanent deletion
/// only works for items with no borrow history; if the RPC refuses (the
/// item was borrowed at least once), it offers to deactivate instead so
/// the accountability record is preserved.
class _DeleteItemButton extends ConsumerWidget {
  const _DeleteItemButton({required this.item, this.visualDensity});

  final Item item;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Delete item',
      visualDensity: visualDensity,
      icon: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      onPressed: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Permanently delete "${item.displayName}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(itemsRepositoryProvider);
    try {
      await repo.deleteItem(
        item.id,
        referencePhotoPath: item.referencePhotoPath,
      );
      ref.invalidate(itemsProvider);
      ref.invalidate(itemStatusesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${item.displayName}".')),
      );
    } on PostgrestException catch (e) {
      final hasHistory =
          e.hint == 'deactivate' || e.message.contains('borrow history');
      if (hasHistory && context.mounted) {
        await _offerDeactivate(context, ref, repo, messenger);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not delete: ${e.message}')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _offerDeactivate(
    BuildContext context,
    WidgetRef ref,
    ItemsRepository repo,
    ScaffoldMessengerState messenger,
  ) async {
    if (!item.active) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '"${item.displayName}" has borrow history, so it can\'t be '
            'deleted. It is already deactivated.',
          ),
        ),
      );
      return;
    }
    final deactivate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep the record instead?'),
        content: Text(
          '"${item.displayName}" has borrow history, so it can\'t be '
          'permanently deleted. Deactivate it instead — it stays in the '
          'records but can no longer be borrowed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (deactivate != true) return;
    try {
      await repo.updateItem(
        item.id,
        name: item.name,
        distinguishingTag: item.distinguishingTag,
        category: item.category,
        owningDepartmentId: item.owningDepartmentId,
        active: false,
        quantity: item.quantity,
        flowType: item.flowType,
      );
      ref.invalidate(itemsProvider);
      ref.invalidate(itemStatusesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Deactivated "${item.displayName}".')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not deactivate the item.')),
      );
    }
  }
}
