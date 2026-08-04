import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/sbs_table.dart';
import '../../approvals/data/approvals_models.dart';
import '../../approvals/data/approvals_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';
import 'admin_page.dart';

/// Below this the table doesn't have room for its columns; the screen
/// drops back to a card-per-user list instead.
const _tableBreakpoint = 760.0;

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
      maxWidth: 1080,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _tableBreakpoint) {
                return _UsersTable(users: filtered);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: filtered.length,
                itemBuilder: (context, i) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UserTile(user: filtered[i]),
                    ).fadeUpAt(i),
              );
            },
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

// ─────────────────────────────────────────────────────────────────────
// Table view (wide screens)
// ─────────────────────────────────────────────────────────────────────

class _UsersTable extends ConsumerWidget {
  const _UsersTable({required this.users});

  final List<UserAccount> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperadmin = ref.watch(isSuperadminProvider);
    final myId = ref.watch(myProfileProvider).value?.id;
    return SbsTable(
      columns: const ['User', 'Type', 'Verification', 'Status', ''],
      rows: [
        for (final user in users)
          SbsRow(
            cells: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(user: user, radius: 17),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          user.username != null ? '@${user.username}' : 'No username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(
                    label: user.isStaff ? 'Staff' : 'Citizen',
                    color: user.isStaff
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  if (user.isSuperadmin)
                    _Tag(label: 'Superadmin', color: Theme.of(context).colorScheme.tertiary),
                ],
              ),
              user.isStaff
                  ? const Text('—')
                  : InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _openReviewDialog(context, ref, user),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Tag(
                            label: user.verified == true ? 'ID verified' : 'Unverified',
                            color: user.verified == true
                                ? const Color(0xFF1F9D65)
                                : const Color(0xFFE07A1F),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
              user.active
                  ? const _Tag(label: 'Active', color: Color(0xFF1F9D65))
                  : _Tag(label: 'Deactivated', color: Theme.of(context).colorScheme.error),
              _UserActions(
                user: user,
                isSelf: myId == user.id,
                viewerIsSuperadmin: isSuperadmin,
              ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Card view (narrow screens)
// ─────────────────────────────────────────────────────────────────────

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
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _openReviewDialog(context, ref, user),
                        child: _Tag(
                          label: user.verified == true
                              ? 'ID verified'
                              : 'Unverified',
                          color: user.verified == true
                              ? const Color(0xFF1F9D65)
                              : const Color(0xFFE07A1F),
                        ),
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
  const _Avatar({required this.user, this.radius = 23});

  final UserAccount user;
  final double radius;

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
          radius: radius,
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

// ─────────────────────────────────────────────────────────────────────
// Actions menu
// ─────────────────────────────────────────────────────────────────────

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
          value: 'reviewId',
          child: _MenuRow(
            icon: Icons.badge_outlined,
            label: user.verified == true ? 'View ID' : 'Review ID',
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
        case 'reviewId':
          await _openReviewDialog(context, ref, user);
          return;
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

// ─────────────────────────────────────────────────────────────────────
// ID review dialog — the actual point of this round: verifying used to be
// a single blind tap; this shows the citizen's submitted ID type/number,
// contact number, and photo before staff decide.
// ─────────────────────────────────────────────────────────────────────

Future<void> _openReviewDialog(
  BuildContext context,
  WidgetRef ref,
  UserAccount user,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ReviewIdDialog(user: user),
  );
}

class _ReviewIdDialog extends ConsumerStatefulWidget {
  const _ReviewIdDialog({required this.user});

  final UserAccount user;

  @override
  ConsumerState<_ReviewIdDialog> createState() => _ReviewIdDialogState();
}

class _ReviewIdDialogState extends ConsumerState<_ReviewIdDialog> {
  bool _busy = false;

  Future<void> _setVerified(bool verified) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setCitizenVerified(widget.user.id, verified);
      ref.invalidate(allUsersProvider);
      ref.invalidate(citizenVerificationProvider(widget.user.id));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update verification.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verification = ref.watch(citizenVerificationProvider(widget.user.id));

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.badge_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.user.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: switch (verification) {
          AsyncData(:final value) => _ReviewIdContent(
            user: widget.user,
            verification: value,
          ),
          AsyncError() => const Text('Could not load this citizen\'s ID details.'),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (verification case AsyncData(:final value))
          value.verified
              ? OutlinedButton(
                  onPressed: _busy ? null : () => _setVerified(false),
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                  child: _busy
                      ? const _ButtonSpinner()
                      : const Text('Un-verify'),
                )
              : FilledButton(
                  onPressed: _busy ? null : () => _setVerified(true),
                  child: _busy
                      ? const _ButtonSpinner()
                      : const Text('Verify identity'),
                ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _ReviewIdContent extends StatelessWidget {
  const _ReviewIdContent({required this.user, required this.verification});

  final UserAccount user;
  final CitizenVerification verification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: verification.verified
                ? const Color(0xFF1F9D65).withValues(alpha: 0.13)
                : const Color(0xFFE07A1F).withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verification.verified ? Icons.verified_user : Icons.gpp_maybe,
                size: 16,
                color: verification.verified
                    ? const Color(0xFF1F9D65)
                    : const Color(0xFFE07A1F),
              ),
              const SizedBox(width: 6),
              Text(
                verification.verified ? 'Identity verified' : 'Not yet verified',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: verification.verified
                      ? const Color(0xFF1F9D65)
                      : const Color(0xFFE07A1F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailRow(label: 'Username', value: user.username != null ? '@${user.username}' : '—'),
        _DetailRow(label: 'Contact number', value: verification.contactNumber),
        _DetailRow(label: 'ID type', value: verification.idType),
        _DetailRow(label: 'ID number', value: verification.idNumber),
        const SizedBox(height: 12),
        Text(
          'ID photo',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (verification.idPhotoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              verification.idPhotoUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (context, error, stack) => Container(
                height: 200,
                alignment: Alignment.center,
                color: scheme.surfaceContainerHighest,
                child: Text(
                  'Could not load ID photo.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No ID photo on file.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
