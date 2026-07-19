import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../features/items/data/items_providers.dart';

/// Shared bottom navigation for the app's main sections.
/// The Approvals tab appears only for staff.
class SBSNavBar extends ConsumerWidget {
  const SBSNavBar({super.key, required this.current});

  /// One of [AppRoutes.home], [AppRoutes.requests], [AppRoutes.items],
  /// [AppRoutes.approvals].
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(isStaffProvider);
    final routes = [
      AppRoutes.home,
      AppRoutes.requests,
      AppRoutes.items,
      if (isStaff) AppRoutes.approvals,
    ];
    final index = routes.indexOf(current).clamp(0, routes.length - 1);

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        if (routes[i] != current) context.go(routes[i]);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Requests',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Items',
        ),
        if (isStaff)
          const NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Approvals',
          ),
      ],
    );
  }
}
