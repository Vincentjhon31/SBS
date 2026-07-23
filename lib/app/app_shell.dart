import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/glossy_background.dart';
import '../features/items/data/items_providers.dart';

/// Wraps the 5 main tabs in one shared Scaffold/NavigationBar via
/// [StatefulNavigationShell] (IndexedStack under the hood) — switching
/// tabs is an instant index swap with no page-transition rebuild, and
/// each tab keeps its own navigation stack and scroll position.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(isStaffProvider);

    final destinations = <_TabDestination>[
      const _TabDestination(
        branchIndex: 0,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
      ),
      const _TabDestination(
        branchIndex: 1,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Requests',
      ),
      const _TabDestination(
        branchIndex: 2,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Items',
      ),
      if (isStaff)
        const _TabDestination(
          branchIndex: 3,
          icon: Icons.approval_outlined,
          selectedIcon: Icons.approval,
          label: 'Approvals',
        ),
      const _TabDestination(
        branchIndex: 4,
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
        label: 'Profile',
      ),
    ];

    var selectedVisualIndex = destinations
        .indexWhere((d) => d.branchIndex == navigationShell.currentIndex);
    if (selectedVisualIndex < 0) selectedVisualIndex = 0;

    return Scaffold(
      body: GlossyBackground(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedVisualIndex,
        onDestinationSelected: (i) {
          final branchIndex = destinations[i].branchIndex;
          // Re-tapping the active tab resets it to its root (initialLocation)
          // instead of doing nothing — matches iOS tab-bar behavior.
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _TabDestination {
  const _TabDestination({
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
