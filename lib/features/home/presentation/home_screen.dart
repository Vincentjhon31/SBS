import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/category_color.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../auth/data/auth_providers.dart';
import '../../borrowing/data/borrow_models.dart';
import '../../borrowing/data/borrow_providers.dart';
import '../../items/data/items_models.dart';
import '../../items/data/items_providers.dart';
import '../../notifications/data/notifications_providers.dart';

/// The first tab. Citizens get the live borrowing Home; staff get the
/// merged management Dashboard (the old Home + Admin Dashboard, unified).
class HomeOrDashboard extends ConsumerWidget {
  const HomeOrDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isStaffProvider)
        ? const StaffDashboardScreen()
        : const HomeScreen();
  }
}

/// Citizen home: a greeting header, a rounded search bar, category pills,
/// and a horizontally-scrolling carousel of large hero item cards — each
/// with a floating "Request" pill overlapping its bottom edge — followed
/// by a compact strip of anything currently borrowed.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  /// null = "All" — same free-text taxonomy as the Items Registry.
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final verified = ref.watch(myCitizenVerifiedProvider);
    final activeRequests = ref.watch(activeRequestsProvider);
    final allRequests = ref.watch(myRequestsProvider).value ?? const [];
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final statuses = ref.watch(itemStatusesProvider).value ?? const {};
    final query = ref.watch(itemsQueryProvider);
    if (_searchController.text != query) {
      _searchController.text = query;
    }

    final available = [
      for (final item in items)
        if (statuses[item.id]?.status == 'available') item,
    ];
    final categories = _categories(available);
    final filtered = [
      for (final item in available)
        if ((_category == null || item.category == _category) &&
            (query.trim().isEmpty ||
                item.name.toLowerCase().contains(query.trim().toLowerCase())))
          item,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      // GlossyBackground already lives in the shared shell (_TabBarShell),
      // so Home only needs the safe-area inset, not another backdrop layer.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myRequestsProvider);
            ref.invalidate(itemsProvider);
            ref.invalidate(itemStatusesProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              switch (profile) {
                AsyncData(:final value) when value != null => _HomeHeader(
                  fullName: value.fullName,
                  unread: ref.watch(unreadCountProvider),
                ).fadeUp(),
                AsyncError() => const Text('Could not load your profile.'),
                _ => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
              if (verified case AsyncData(value: false)) ...[
                const SizedBox(height: 14),
                const _VerificationBanner().fadeUp(
                  delay: const Duration(milliseconds: 60),
                ),
              ],
              const SizedBox(height: 20),
              _SearchBar(
                controller: _searchController,
                onChanged: (v) => ref.read(itemsQueryProvider.notifier).set(v),
                onFilterTap: () => context.go(AppRoutes.items),
              ).fadeUp(delay: const Duration(milliseconds: 100)),
              const SizedBox(height: 18),
              _StatusStrip(requests: allRequests).fadeUp(
                delay: const Duration(milliseconds: 150),
              ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: 'Available to Borrow',
                onSeeAll: () => context.go(AppRoutes.items),
              ).fadeUp(delay: const Duration(milliseconds: 200)),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                _CategoryPills(
                  categories: categories,
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                ).fadeUp(delay: const Duration(milliseconds: 240)),
              ],
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const _EmptyHint(
                  icon: Icons.inventory_2_outlined,
                  text: 'Nothing available right now.',
                  hint: 'Check back later, or browse the full registry.',
                ).fadeUp(delay: const Duration(milliseconds: 280))
              else
                _HeroCarousel(
                  items: filtered,
                ).fadeUp(delay: const Duration(milliseconds: 280)),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'My Borrowed Items',
                onSeeAll: () => context.go(AppRoutes.requests),
              ).fadeUp(delay: const Duration(milliseconds: 320)),
              const SizedBox(height: 12),
              if (activeRequests.isEmpty)
                const _EmptyHint(
                  icon: Icons.check_circle_outline,
                  text: 'Nothing borrowed right now.',
                  hint: 'Anything you request will show up here.',
                ).fadeUp(delay: const Duration(milliseconds: 360))
              else
                for (final (i, request) in activeRequests.take(3).indexed)
                  _BorrowedItemTile(request: request).fadeUpAt(i + 6),
            ],
          ),
        ),
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.fullName, required this.unread});

  final String fullName;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $first',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome to ${AppConstants.appName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RoundIconButton(
          icon: Icons.notifications_outlined,
          badge: unread,
          onTap: () => context.push(AppRoutes.notifications),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.go(AppRoutes.profile),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(
              _initials(fullName),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Badge.count(
          count: badge,
          isLabelVisible: badge > 0,
          child: Icon(icon, size: 21, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Identity verification pending — an LGU approver will verify '
              'your ID on your first request.',
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items…',
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(icon: Icons.tune, onTap: onFilterTap),
      ],
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
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Pill(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            _Pill(
              label: c,
              selected: selected == c,
              onTap: () => onSelected(c),
              accentColor: categoryColor(c).$2,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Category color-coding for the unselected state; null for the neutral
  /// "All" pill. Selected state stays the high-contrast dark fill so the
  /// current filter is always unambiguous regardless of category color.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unselectedColor = accentColor ?? scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          // A transparent fill let the busy blob backdrop show straight
          // through the unselected pills — a solid tint (matching the
          // items registry's category chips) keeps them legible.
          color: selected
              ? scheme.onSurface
              : unselectedColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.onSurface : unselectedColor.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.surface : unselectedColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.icon, this.hint});

  final String text;
  final IconData icon;

  /// Optional second line telling the reader what to do about it — an
  /// empty state that only says "nothing here" leaves them stuck.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three counts a borrower actually cares about, sitting between the
/// search bar and the catalogue: what is waiting on staff, what they
/// currently hold, and anything late. Taps jump to My Requests.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.requests});

  final List<BorrowRequest> requests;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var pending = 0;
    var active = 0;
    var overdue = 0;
    for (final r in requests) {
      switch (r.status) {
        case 'pending':
          pending++;
        case 'approved' || 'released':
          active++;
        case 'overdue':
          overdue++;
      }
    }
    final cards = <(IconData, String, int, Color)>[
      (Icons.hourglass_empty, 'Pending', pending, scheme.tertiary),
      (Icons.inventory_2_outlined, 'With you', active, scheme.primary),
      (Icons.warning_amber_rounded, 'Overdue', overdue, scheme.error),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go(AppRoutes.requests),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cards[i].$3 > 0 && i == 2
                        ? scheme.error.withValues(alpha: 0.45)
                        : scheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(cards[i].$1, size: 18, color: cards[i].$4),
                    const SizedBox(height: 8),
                    Text(
                      '${cards[i].$3}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cards[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontally-scrolling row of large hero cards, sized to peek the next
/// card at the edge (matches the reference: one dominant card with the
/// next one just visible).
class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * 0.78).clamp(220.0, 300.0);
        final cardHeight = cardWidth * 1.2;
        return SizedBox(
          height: cardHeight + 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(width: 16),
            itemBuilder: (context, i) => _HeroItemCard(
              item: items[i],
              width: cardWidth,
              height: cardHeight,
            ),
          ),
        );
      },
    );
  }
}

class _HeroItemCard extends ConsumerWidget {
  const _HeroItemCard({
    required this.item,
    required this.width,
    required this.height,
  });

  final Item item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(itemStatusesProvider).value?[item.id];
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: InkWell(
              onTap: () => context.push(AppRoutes.itemCalendar, extra: item),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroImage(path: item.referencePhotoPath),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.5, 1],
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    if (status != null && status.hasMultipleUnits)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _FrostedLabel(
                          text:
                              '${status.availableCount} of ${status.quantity} available',
                        ),
                      ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _FrostedIconButton(
                        icon: Icons.calendar_month_outlined,
                        onTap: () =>
                            context.push(AppRoutes.itemCalendar, extra: item),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.category != null)
                            Text(
                              item.category!.toUpperCase(),
                              style: TextStyle(
                                // The pastel (not the paired dark-text)
                                // half of the pair, since this sits on a
                                // dark photo scrim, not a light chip.
                                color: categoryColor(item.category).$1,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            item.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -18,
            child: _RequestPillButton(
              onTap: () => context.push(AppRoutes.requestNew, extra: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends ConsumerWidget {
  const _HeroImage({this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 56,
        color: scheme.onPrimaryContainer,
      ),
    );
    if (path == null) return fallback();
    final url = ref.watch(itemPhotoUrlProvider(path!));
    return switch (url) {
      AsyncData(:final value) => Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, e, s) => fallback(),
      ),
      _ => fallback(),
    };
  }
}

class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

class _FrostedLabel extends StatelessWidget {
  const _FrostedLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _RequestPillButton extends StatelessWidget {
  const _RequestPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14161D),
      borderRadius: BorderRadius.circular(28),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Request',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _BorrowedItemTile extends StatelessWidget {
  const _BorrowedItemTile({required this.request});

  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.requests),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.inventory_2_outlined,
                color: scheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.itemLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.dueAt != null
                        ? 'Due back ${formatDate(request.dueAt!)}'
                        : 'From ${formatDate(request.requestedFrom)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RequestStatusChip(status: request.status),
          ],
        ),
      ),
    );
  }
}
