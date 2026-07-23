import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/glossy_background.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/items/data/items_providers.dart';

/// Wraps the main tabs in one shared Scaffold/NavigationBar via
/// [StatefulNavigationShell] (IndexedStack under the hood) — switching
/// tabs is an instant index swap with no page-transition rebuild, and
/// each tab keeps its own navigation stack and scroll position.
///
/// Staff/superadmin accounts are management/back-office work and belong
/// on the website, not the installed mobile app — the mobile app is
/// citizens-only. This is a client-side UX gate, not a security
/// boundary: RLS already enforces the real access rules regardless of
/// which surface someone uses.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(isStaffProvider);

    if (!kIsWeb && isStaff) {
      return const _StaffUseWebScreen();
    }

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

class _StaffUseWebScreen extends ConsumerWidget {
  const _StaffUseWebScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.laptop_mac_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Staff accounts use the ${AppConstants.appName} website',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Approvals, item management, and the superadmin dashboard '
                  'are handled through a web browser now. This mobile app '
                  'is for citizen borrowers only.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
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
