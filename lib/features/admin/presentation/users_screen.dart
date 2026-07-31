import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/glossy_background.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';

enum _UserFilter { all, citizens, staff }

/// Superadmin/staff account management: every profile in the system, with
/// actions scoped to what the signed-in user is allowed to do (staff can
/// verify/deactivate citizens; only superadmins can promote/demote or
/// grant/revoke superadmin). Modeled on DepartmentsScreen's list +
/// dialog-confirmation pattern.
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

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Users')),
      body: GlossyBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name or username…',
                    ),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == _UserFilter.all,
                        onSelected: (_) => setState(() => _filter = _UserFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Citizens'),
                        selected: _filter == _UserFilter.citizens,
                        onSelected: (_) => setState(() => _filter = _UserFilter.citizens),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Staff'),
                        selected: _filter == _UserFilter.staff,
                        onSelected: (_) => setState(() => _filter = _UserFilter.staff),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (users) {
                    AsyncData(:final value) => _buildList(value),
                    AsyncError(:final error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load users.\n$error'),
                      ),
                    ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<UserAccount> all) {
    final filtered = all.where((u) {
      final matchesFilter = switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.citizens => !u.isStaff,
        _UserFilter.staff => u.isStaff,
      };
      if (!matchesFilter) return false;
      if (_query.isEmpty) return true;
      return u.fullName.toLowerCase().contains(_query) ||
          (u.username?.toLowerCase().contains(_query) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No users match.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _UserTile(user: filtered[i]),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isStaff
              ? scheme.secondaryContainer
              : scheme.primaryContainer,
          child: Icon(user.isStaff ? Icons.badge_outlined : Icons.person_outline),
        ),
        title: Text(user.fullName),
        subtitle: Text(
          [
            user.username != null ? '@${user.username}' : 'No username',
            user.isStaff ? 'Staff' : 'Citizen',
            if (user.isSuperadmin) 'Superadmin',
            if (user.verified == true) 'ID verified',
            if (!user.active) 'Deactivated',
          ].join(' • '),
          style: !user.active ? TextStyle(color: scheme.error) : null,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handle(context, ref, action),
          itemBuilder: (context) => [
            if (!user.isStaff)
              PopupMenuItem(
                value: 'verify',
                child: Text(
                  user.verified == true ? 'Un-verify ID' : 'Verify ID',
                ),
              ),
            if (isSuperadmin && !isSelf) ...[
              PopupMenuItem(
                value: 'toggleType',
                child: Text(
                  user.isStaff ? 'Demote to citizen' : 'Promote to staff',
                ),
              ),
              if (user.isStaff)
                PopupMenuItem(
                  value: 'toggleSuperadmin',
                  child: Text(
                    user.isSuperadmin ? 'Revoke superadmin' : 'Grant superadmin',
                  ),
                ),
            ],
            if (!isSelf && (!user.isStaff || isSuperadmin))
              PopupMenuItem(
                value: 'toggleActive',
                child: Text(user.active ? 'Deactivate account' : 'Reactivate account'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
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
        title: const Text('Deactivate account?'),
        content: Text(
          '"${user.fullName}" will be signed out and unable to sign back '
          'in until reactivated.',
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
