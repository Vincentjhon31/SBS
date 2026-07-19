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
                  isStaff: isStaff,
                  onRefresh: () async => ref.invalidate(itemsProvider),
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
    required this.isStaff,
    required this.onRefresh,
  });

  final List<Item> items;
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
          return ListTile(
            leading: _ItemThumbnail(path: item.referencePhotoPath),
            title: Text(item.displayName),
            subtitle: Text(
              [
                if (item.category != null) item.category!,
                item.departmentName ?? 'Shared LGU pool',
              ].join(' • '),
            ),
            trailing: item.active
                ? null
                : Chip(
                    label: const Text('Inactive'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  ),
            onTap: isStaff
                ? () => context.go(AppRoutes.itemEdit, extra: item)
                : null,
          );
        },
      ),
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
