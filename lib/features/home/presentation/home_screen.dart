import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/item_status_chip.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../../core/widgets/sbs_nav_bar.dart';
import '../../auth/data/auth_providers.dart';
import '../../borrowing/data/borrow_models.dart';
import '../../borrowing/data/borrow_providers.dart';
import '../../items/data/items_models.dart';
import '../../items/data/items_providers.dart';
import '../../notifications/data/notifications_providers.dart';

enum _ProfileMenuAction { settings, signOut }

/// Live dashboard: active borrowed items and items available right now,
/// plus quick access to notifications, settings, and sign-out.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final verified = ref.watch(myCitizenVerifiedProvider);
    final activeRequests = ref.watch(activeRequestsProvider);
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final statuses = ref.watch(itemStatusesProvider).value ?? const {};
    final available = [
      for (final item in items)
        if (statuses[item.id]?.status == 'available') item,
    ];

    return Scaffold(
      bottomNavigationBar: const SBSNavBar(current: AppRoutes.home),
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge.count(
              count: ref.watch(unreadCountProvider),
              isLabelVisible: ref.watch(unreadCountProvider) > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go(AppRoutes.notifications),
          ),
          PopupMenuButton<_ProfileMenuAction>(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (action) {
              switch (action) {
                case _ProfileMenuAction.settings:
                  context.go(AppRoutes.settings);
                case _ProfileMenuAction.signOut:
                  ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ProfileMenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenuAction.signOut,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRequestsProvider);
          ref.invalidate(itemsProvider);
          ref.invalidate(itemStatusesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            switch (profile) {
              AsyncData(:final value) when value != null => Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome, ${value.fullName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        value.isStaff ? 'LGU Staff' : 'Citizen Borrower',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              AsyncError() => const Text('Could not load your profile.'),
              _ => const SizedBox(
                  height: 32,
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
            if (verified case AsyncData(value: false)) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Identity verification pending — an LGU approver '
                          'will verify your ID on your first request.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'My Borrowed Items',
              onSeeAll: () => context.go(AppRoutes.requests),
            ),
            const SizedBox(height: 8),
            if (activeRequests.isEmpty)
              const _EmptyHint(text: 'Nothing borrowed right now.')
            else
              for (final request in activeRequests.take(3))
                _BorrowedItemTile(request: request),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Available to Borrow',
              onSeeAll: () => context.go(AppRoutes.items),
            ),
            const SizedBox(height: 8),
            if (available.isEmpty)
              const _EmptyHint(text: 'Nothing available right now.')
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final item in available.take(4))
                    _AvailableItemCard(item: item),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _BorrowedItemTile extends StatelessWidget {
  const _BorrowedItemTile({required this.request});

  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(request.itemLabel),
        subtitle: request.dueAt != null
            ? Text('Due back ${_date(request.dueAt!)}')
            : Text('From ${_date(request.requestedFrom)}'),
        trailing: RequestStatusChip(status: request.status),
        onTap: () => context.go(AppRoutes.requests),
      ),
    );
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _AvailableItemCard extends ConsumerWidget {
  const _AvailableItemCard({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ItemThumbnail(path: item.referencePhotoPath),
                const SizedBox(width: 8),
                const Expanded(child: ItemStatusChip(status: 'available')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.displayName,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.category != null)
              Text(
                item.category!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    context.go(AppRoutes.requestNew, extra: item),
                child: const Text('Request'),
              ),
            ),
          ],
        ),
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
      return const CircleAvatar(
        radius: 16,
        child: Icon(Icons.inventory_2_outlined, size: 16),
      );
    }
    final url = ref.watch(itemPhotoUrlProvider(path!));
    return switch (url) {
      AsyncData(:final value) => CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(value),
          onBackgroundImageError: (_, s) {},
        ),
      _ => const CircleAvatar(
          radius: 16,
          child: Icon(Icons.image_outlined, size: 16),
        ),
    };
  }
}
