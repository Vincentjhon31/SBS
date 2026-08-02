import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_animations.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';
import 'admin_page.dart';

enum _UserFilter { all, citizens, staff, unverified, deactivated }

extension on _UserFilter {
  String get label => switch (this) {
    _UserFilter.all => 'All',
    _UserFilter.citizens => 'Citizens',
    _UserFilter.staff => 'Staff',
    _UserFilter.unverified => 'Unverified',
    _UserFilter.deactivated => 'Deactivated',
  };
}

bool _matchesFilter(UserAccount u, _UserFilter filter) => switch (filter) {
  _UserFilter.all => true,
  _UserFilter.citizens => !u.isStaff,
  _UserFilter.staff => u.isStaff,
  _UserFilter.unverified => !u.isStaff && u.verified != true,
  _UserFilter.deactivated => !u.active,
};

/// Account management: every profile in the system, with the actions
/// scoped to what the signed-in user may actually do — staff can verify
/// and deactivate citizens; only superadmins can change roles, grant
/// superadmin, or touch another staff account.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _UserFilter _filter = _UserFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(UserAccount u) {
    if (!_matchesFilter(u, _filter)) return false;
    if (_query.isEmpty) return true;
    return u.fullName.toLowerCase().contains(_query) ||
        (u.username?.toLowerCase().contains(_query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);
    final all = users.value ?? const <UserAccount>[];
    final filtered = all.where(_matches).toList();

    return AdminPage(
      icon: Icons.group_outlined,
      title: 'Users',
      subtitle: 'Verify identities, change roles, and deactivate accounts.',
      accent: const Color(0xFF6750A4),
      actions: [
        if (users.isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(allUsersProvider),
            icon: const Icon(Icons.refresh),
          ),
      ],
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name or username…',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _UserFilter.values) ...[
                  if (f != _UserFilter.all) const SizedBox(width: 8),
                  _CountChip(
                    label: f.label,
                    // Counted against the whole set, not the filtered one,
                    // so the chips read as a standing summary rather than
                    // reflecting whichever chip is currently selected.
                    count: all.where((u) => _matchesFilter(u, f)).length,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      child: switch (users) {
        AsyncError(:final error) => AdminEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load users',
          hint: '$error',
        ),
        _ when all.isEmpty && users.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when filtered.isEmpty => AdminEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No users match',
          hint: _query.isEmpty
              ? 'Nobody falls under this filter yet.'
              : 'Try a different name or username.',
        ),
        _ => RefreshIndicator(
          onRefresh: () async => ref.invalidate(allUsersProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: filtered.length,
            itemBuilder: (context, i) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UserTile(user: filtered[i]),
                ).fadeUpAt(i),
          ),
        ),
      },
    );
  }

}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.22)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isSuperadmin = ref.watch(isSuperadminProvider);
    final myId = ref.watch(myProfileProvider).value?.id;
    final isSelf = myId == user.id;

    return AdminCard(
      child: Row(
        children: [
          _Avatar(user: user),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      _Tag(label: 'You', color: scheme.onSurfaceVariant),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.username != null ? '@${user.username}' : 'No username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      label: user.isStaff ? 'Staff' : 'Citizen',
                      color: user.isStaff ? scheme.tertiary : scheme.primary,
                    ),
                    if (user.isSuperadmin)
                      _Tag(label: 'Superadmin', color: scheme.tertiary),
                    if (!user.isStaff)
                      _Tag(
                        label: user.verified == true
                            ? 'ID verified'
                            : 'Unverified',
                        color: user.verified == true
                            ? const Color(0xFF1F9D65)
                            : const Color(0xFFE07A1F),
                      ),
                    if (!user.active)
                      _Tag(label: 'Deactivated', color: scheme.error),
                  ],
                ),
              ],
            ),
          ),
          _UserActions(
            user: user,
            isSelf: isSelf,
            viewerIsSuperadmin: isSuperadmin,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = user.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();
    final bg = user.isStaff ? scheme.tertiaryContainer : scheme.primaryContainer;
    final fg = user.isStaff
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    return Stack(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: user.active ? bg : scheme.surfaceContainerHighest,
          foregroundColor: user.active ? fg : scheme.onSurfaceVariant,
          child: Text(
            initials,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        if (!user.active)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block, size: 13, color: scheme.error),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserActions extends ConsumerWidget {
  const _UserActions({
    required this.user,
    required this.isSelf,
    required this.viewerIsSuperadmin,
  });

  final UserAccount user;
  final bool isSelf;
  final bool viewerIsSuperadmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <PopupMenuEntry<String>>[
      if (!user.isStaff)
        PopupMenuItem(
          value: 'verify',
          child: _MenuRow(
            icon: user.verified == true
                ? Icons.gpp_maybe_outlined
                : Icons.verified_user_outlined,
            label: user.verified == true ? 'Un-verify ID' : 'Verify ID',
          ),
        ),
      if (viewerIsSuperadmin && !isSelf) ...[
        PopupMenuItem(
          value: 'toggleType',
          child: _MenuRow(
            icon: user.isStaff
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            label: user.isStaff ? 'Demote to citizen' : 'Promote to staff',
          ),
        ),
        if (user.isStaff)
          PopupMenuItem(
            value: 'toggleSuperadmin',
            child: _MenuRow(
              icon: Icons.shield_outlined,
              label: user.isSuperadmin
                  ? 'Revoke superadmin'
                  : 'Grant superadmin',
            ),
          ),
      ],
      if (!isSelf && (!user.isStaff || viewerIsSuperadmin)) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggleActive',
          child: _MenuRow(
            icon: user.active ? Icons.block : Icons.check_circle_outline,
            label: user.active ? 'Deactivate account' : 'Reactivate account',
            danger: user.active,
          ),
        ),
      ],
    ];

    if (items.isEmpty) {
      return const SizedBox(width: 8);
    }
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => items,
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(adminRepositoryProvider);
    try {
      switch (action) {
        case 'verify':
          await repo.setCitizenVerified(user.id, user.verified != true);
        case 'toggleType':
          await repo.setUserType(user.id, user.isStaff ? 'citizen' : 'staff');
        case 'toggleSuperadmin':
          await repo.setSuperadmin(user.id, !user.isSuperadmin);
        case 'toggleActive':
          if (user.active) {
            final confirmed = await _confirmDeactivate(context);
            if (confirmed != true) return;
          }
          await repo.setAccountActive(user.id, !user.active);
      }
      ref.invalidate(allUsersProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not complete that action.')),
      );
    }
  }

  Future<bool?> _confirmDeactivate(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
        title: const Text('Deactivate account?'),
        content: Text(
          '"${user.fullName}" will be signed out and unable to sign back '
          'in until an administrator reactivates them.',
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
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
