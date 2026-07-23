import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/glossy_background.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/items/data/items_providers.dart';
import 'router.dart';

/// Whether the staff web sidebar is showing full labels (true) or has
/// been collapsed to an icon-only rail (false) via the hamburger toggle.
/// Session-only UI state — not worth persisting server-side.
class SidebarExpanded extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarExpandedProvider = NotifierProvider<SidebarExpanded, bool>(
  SidebarExpanded.new,
);

/// Wraps the main tabs via [StatefulNavigationShell] (IndexedStack under
/// the hood) — switching tabs is an instant index swap with no
/// page-transition rebuild, and each tab keeps its own navigation stack
/// and scroll position.
///
/// Staff/superadmin accounts are management/back-office work and belong
/// on the website, not the installed mobile app:
/// - Native platforms + staff → blocked, told to use the website.
/// - Web + staff → a desktop admin layout (sidebar navigation rail).
/// - Everyone else (citizens, any platform) → the original bottom tab bar.
/// This is a client-side UX gate, not a security boundary: RLS already
/// enforces the real access rules regardless of which surface is used.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(isStaffProvider);

    if (!kIsWeb && isStaff) {
      return const _StaffUseWebScreen();
    }
    if (kIsWeb && isStaff) {
      return _SidebarShell(navigationShell: navigationShell);
    }
    return _TabBarShell(navigationShell: navigationShell, isStaff: isStaff);
  }
}

/// Original mobile-style shell: bottom NavigationBar. Used by citizens on
/// any platform (mobile app or web browser) — unchanged from before.
class _TabBarShell extends StatelessWidget {
  const _TabBarShell({required this.navigationShell, required this.isStaff});

  final StatefulNavigationShell navigationShell;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final destinations = _tabDestinations(isStaff);
    var selectedVisualIndex = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );
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

/// Desktop admin layout for staff on web: a NavigationRail sidebar
/// instead of a bottom bar, and the content area gets breathing room
/// instead of staying phone-width. The rail collapses to an icon-only
/// strip via the hamburger toggle, like Notion/Linear/Gmail's desktop
/// nav, so staff can reclaim width on smaller laptop screens.
class _SidebarShell extends ConsumerWidget {
  const _SidebarShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperadmin = ref.watch(isSuperadminProvider);
    final profile = ref.watch(myProfileProvider).value;
    final expanded = ref.watch(sidebarExpandedProvider);
    final destinations = _tabDestinations(true);
    var selectedIndex = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );
    if (selectedIndex < 0) selectedIndex = 0;

    void goBranch(int branchIndex) => navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: GlossyBackground(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              extended: expanded,
              minExtendedWidth: 232,
              backgroundColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) =>
                  goBranch(destinations[i].branchIndex),
              leading: _RailHeader(
                expanded: expanded,
                onToggle: () =>
                    ref.read(sidebarExpandedProvider.notifier).toggle(),
              ),
              // NavigationRail's `trailing` slot does not provide a
              // bounded-height context, so Expanded/Align-to-bottom here
              // silently breaks layout (confirmed by bisection) — keep
              // everything in it non-flexible.
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSuperadmin) _AdminShortcut(expanded: expanded),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      height: 17,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  _AccountFooter(
                    expanded: expanded,
                    fullName: profile?.fullName,
                    onTap: () => goBranch(4),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: expanded ? '' : d.label,
                      child: Icon(d.icon),
                    ),
                    selectedIcon: Tooltip(
                      message: expanded ? '' : d.label,
                      child: Icon(d.selectedIcon),
                    ),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: const Icon(Icons.menu),
      tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
      onPressed: onToggle,
    );
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: toggle,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          toggle,
          const SizedBox(width: 4),
          Icon(
            Icons.event_available,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _AdminShortcut extends StatelessWidget {
  const _AdminShortcut({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.admin),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 16 : 0,
            vertical: 12,
          ),
          child: expanded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.admin_panel_settings_outlined),
                    SizedBox(width: 12),
                    Text('Admin dashboard'),
                  ],
                )
              : const Tooltip(
                  message: 'Admin dashboard',
                  child: Center(
                    child: Icon(Icons.admin_panel_settings_outlined),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Shows who's signed in — an avatar (initials) plus name when expanded,
/// just the avatar when collapsed. Taps open the Profile tab, the same
/// destination the rail's own Profile icon leads to.
class _AccountFooter extends StatelessWidget {
  const _AccountFooter({
    required this.expanded,
    required this.fullName,
    required this.onTap,
  });

  final bool expanded;
  final String? fullName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initials(fullName),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Tooltip(message: fullName ?? '', child: avatar),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullName ?? 'Loading…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'LGU Staff',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
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

List<_TabDestination> _tabDestinations(bool isStaff) => [
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
