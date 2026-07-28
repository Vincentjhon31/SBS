import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/background_style_controller.dart';
import '../core/widgets/glossy_background.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/items/data/items_providers.dart';
import '../features/notifications/data/notifications_providers.dart';
import '../features/settings/data/app_update_providers.dart';
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

/// Mobile-style shell for citizens (any platform): content fills the
/// screen behind a floating, icon-only "pill" tab bar — a dark rounded
/// stadium hovering above the bottom edge rather than a bar flush against
/// it, matching the travel-app reference look requested for the mobile
/// design.
class _TabBarShell extends ConsumerWidget {
  const _TabBarShell({required this.navigationShell, required this.isStaff});

  final StatefulNavigationShell navigationShell;
  final bool isStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _tabDestinations(isStaff);
    var selectedVisualIndex = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );
    if (selectedVisualIndex < 0) selectedVisualIndex = 0;
    final hasPendingUpdate = ref.watch(pendingUpdateProvider) != null;

    return Scaffold(
      // NOT extendBody: each branch screen is its own nested Scaffold, and
      // some (My Requests' "New request") have their own FAB, which floats
      // to the bottom-right of ITS body. extendBody stretches that body
      // behind the floating pill bar, so the FAB would land behind/under
      // it. Leaving extendBody off makes this outer Scaffold reserve the
      // pill's height as normal — the FAB then sits correctly above it,
      // just like the pill bar reserving space from a regular bottom bar.
      body: GlossyBackground(child: navigationShell),
      bottomNavigationBar: _FloatingPillNavBar(
        destinations: destinations,
        selectedIndex: selectedVisualIndex,
        // Profile is always the last tab (branchIndex 4) — see
        // _tabDestinations below.
        updateDotBranchIndex: hasPendingUpdate ? 4 : null,
        onSelect: (i) {
          final branchIndex = destinations[i].branchIndex;
          // Re-tapping the active tab resets it to its root (initialLocation)
          // instead of doing nothing — matches iOS tab-bar behavior.
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _FloatingPillNavBar extends StatelessWidget {
  const _FloatingPillNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.updateDotBranchIndex,
  });

  final List<_TabDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Shows a small dot on whichever destination has this branchIndex (the
  /// Profile tab, when an app update is pending) — null shows no dot.
  final int? updateDotBranchIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF14161D),
          borderRadius: BorderRadius.circular(31),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (i, d) in destinations.indexed)
              _PillNavItem(
                icon: i == selectedIndex ? d.selectedIcon : d.icon,
                label: d.label,
                selected: i == selectedIndex,
                showDot: d.branchIndex == updateDotBranchIndex,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Badge(
            isLabelVisible: showDot,
            backgroundColor: Colors.redAccent,
            child: Icon(
              icon,
              size: 22,
              color: selected ? const Color(0xFF14161D) : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop admin layout for staff on web, styled like a classic admin
/// panel (Laravel Nova / AdminLTE / Filament): a solid dark sidebar with
/// grouped menu items on the left, a top header bar (page title, item
/// search, notifications, account menu), and a light-gray content canvas
/// where cards read as white panels. The sidebar collapses to an
/// icon-only strip via the hamburger toggle.
class _SidebarShell extends ConsumerWidget {
  const _SidebarShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final style = ref.watch(backgroundStyleProvider);
    // Glossy/blob paint their own colored backdrop; the flat gray/surface
    // canvas below is only needed for the "Solid" choice, otherwise it'd
    // just hide the backdrop behind an opaque panel.
    final useBackdrop = style != BackgroundStyle.solid;

    void goBranch(int branchIndex) => navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );

    // Gray canvas + white cards in light mode (the admin-panel classic);
    // dark mode's default card color already contrasts with the surface.
    final content = Container(
      color: useBackdrop
          ? Colors.transparent
          : (light ? theme.colorScheme.surfaceContainer : theme.colorScheme.surface),
      child: light
          ? Theme(
              data: theme.copyWith(
                cardTheme: theme.cardTheme.copyWith(
                  color: theme.colorScheme.surface,
                ),
              ),
              child: navigationShell,
            )
          : navigationShell,
    );

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SideNav(
          currentBranch: navigationShell.currentIndex,
          onSelect: goBranch,
        ),
        Expanded(
          child: Column(
            children: [
              _TopBar(
                currentBranch: navigationShell.currentIndex,
                onSelectBranch: goBranch,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: useBackdrop ? GlossyBackground(child: body) : body,
    );
  }
}

/// Solid, always-dark sidebar (independent of the app's light/dark mode),
/// tinted toward the user's accent seed. Built by hand rather than with
/// NavigationRail so the bottom account footer can actually pin to the
/// bottom (NavigationRail's trailing slot has no bounded height) and so
/// menu items can be grouped under section labels.
class _SideNav extends ConsumerWidget {
  const _SideNav({required this.currentBranch, required this.onSelect});

  final int currentBranch;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    final profile = ref.watch(myProfileProvider).value;
    final bg = Color.alphaBlend(
      AppConstants.seedColor.withValues(alpha: 0.22),
      const Color(0xFF0C1017),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: expanded ? 248 : 76,
      child: Material(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () =>
                        ref.read(sidebarExpandedProvider.notifier).toggle(),
                    tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
                    icon: const Icon(Icons.menu),
                    color: Colors.white70,
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 2),
                    // White chip behind the full-color logo so its dark
                    // outlines stay readable on the dark sidebar.
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(AppConstants.logoAsset, height: 30),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _SectionLabel('MENU', expanded: expanded),
            for (final d in _tabDestinations(true))
              _NavItem(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
                selected: currentBranch == d.branchIndex,
                expanded: expanded,
                onTap: () => onSelect(d.branchIndex),
              ),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            _AccountFooter(
              expanded: expanded,
              fullName: profile?.fullName,
              onTap: () => onSelect(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.expanded});

  final String text;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 10, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    final item = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 12 : 0,
          vertical: 11,
        ),
        child: Row(
          mainAxisAlignment: expanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, size: 22, color: color),
            if (expanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: expanded ? item : Tooltip(message: label, child: item),
    );
  }
}

/// Shows who's signed in — an avatar (initials) plus name when expanded,
/// just the avatar when collapsed. Taps open the Profile tab.
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
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: Colors.white24,
      child: Text(
        _initials(fullName),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
    if (!expanded) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Tooltip(message: fullName ?? '', child: avatar),
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'LGU Staff',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

enum _AccountAction { profile, settings, signOut }

/// Header bar above the content area: current page title on the left;
/// item search, notifications, and the account dropdown on the right —
/// the standard admin-panel top chrome.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.currentBranch, required this.onSelectBranch});

  final int currentBranch;
  final ValueChanged<int> onSelectBranch;

  static const _titles = {
    0: 'Dashboard',
    2: 'Items Registry',
    3: 'Approvals',
    4: 'Profile',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(myProfileProvider).value;
    final unread = ref.watch(unreadCountProvider);

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          return Row(
            children: [
              Text(
                _titles[currentBranch] ?? AppConstants.appName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (wide) ...[
                SizedBox(
                  width: 280,
                  child: _HeaderSearch(
                    onSubmit: (query) {
                      ref.read(itemsQueryProvider.notifier).set(query);
                      onSelectBranch(2);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Notifications',
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => context.push(AppRoutes.notifications),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_AccountAction>(
                tooltip: 'Account',
                offset: const Offset(0, 52),
                onSelected: (action) => switch (action) {
                  _AccountAction.profile => onSelectBranch(4),
                  _AccountAction.settings => context.push(AppRoutes.settings),
                  _AccountAction.signOut =>
                    ref.read(authRepositoryProvider).signOut(),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _AccountAction.profile,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.account_circle_outlined),
                      title: Text('Profile'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _AccountAction.settings,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _AccountAction.signOut,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout, color: scheme.error),
                      title: Text(
                        'Sign out',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          _initials(profile?.fullName),
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 8),
                        Text(
                          profile?.fullName ?? '…',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderSearch extends StatefulWidget {
  const _HeaderSearch({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<_HeaderSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmit,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search items…',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
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

List<_TabDestination> _tabDestinations(bool isStaff) => [
  // Branch 0: citizens get the borrowing Home; staff get the management
  // Dashboard (the old Home + Admin Dashboard, merged).
  _TabDestination(
    branchIndex: 0,
    icon: isStaff ? Icons.space_dashboard_outlined : Icons.home_outlined,
    selectedIcon: isStaff ? Icons.space_dashboard : Icons.home,
    label: isStaff ? 'Dashboard' : 'Home',
  ),
  // Self-service borrowing is a citizen thing — staff manage requests
  // through Approvals (and log walk-ins), so they don't get this tab.
  if (!isStaff)
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
