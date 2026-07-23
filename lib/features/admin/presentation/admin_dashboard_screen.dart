import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';

/// Full oversight bundle: cross-department stats, department/staff
/// assignment, and shortcuts to things that are already staff-wide
/// (Approvals now shows every department to a superadmin via RLS;
/// the deletion queue lives in Settings).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperadmin = ref.watch(isSuperadminProvider);

    if (!isSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Superadmin Dashboard')),
        body: const Center(child: Text('Not authorized.')),
      );
    }

    final stats = ref.watch(superadminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Superadmin Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superadminStatsProvider);
          ref.invalidate(allMembershipsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            switch (stats) {
              AsyncData(:final value) => _StatsGrid(stats: value),
              AsyncError() => const Text('Could not load stats.'),
              _ => const Center(child: CircularProgressIndicator()),
            },
            const SizedBox(height: 24),
            Text('Departments & Staff',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _DepartmentsPanel(),
            const SizedBox(height: 24),
            Text('Shortcuts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.approval_outlined),
                    title: const Text('All Approvals'),
                    subtitle: const Text(
                        'You see every department\'s requests here now'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.approvals),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: const Text('Account Deletion Requests'),
                    subtitle: const Text('In Settings — staff-wide queue'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.settings),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final SuperadminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Items', stats.totalItems, Icons.inventory_2_outlined),
      ('Departments', stats.totalDepartments, Icons.apartment_outlined),
      ('Staff', stats.totalStaff, Icons.badge_outlined),
      ('Citizens', stats.totalCitizens, Icons.people_outline),
      ('Verified citizens', stats.verifiedCitizens, Icons.verified_user_outlined),
      ('Unverified citizens', stats.unverifiedCitizens, Icons.gpp_maybe_outlined),
      ('Pending requests', stats.pendingRequests, Icons.hourglass_top),
      ('Active loans', stats.activeLoans, Icons.outbound),
      ('Overdue', stats.overdueRequests, Icons.warning_amber),
      ('Deletion requests', stats.pendingDeletionRequests, Icons.person_remove_outlined),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        for (final (label, value, icon) in tiles) _StatTile(label, value, icon),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final warn = label == 'Overdue' && value > 0;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: warn ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: warn ? scheme.error : scheme.primary),
            const Spacer(),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DepartmentsPanel extends ConsumerWidget {
  const _DepartmentsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);
    final memberships = ref.watch(allMembershipsProvider);
    final staff = ref.watch(allStaffProvider);

    if (departments is! AsyncData || memberships is! AsyncData) {
      return const Center(child: CircularProgressIndicator());
    }
    final depts = departments.value!;
    final members = memberships.value!;

    return Column(
      children: [
        for (final dept in depts)
          Card(
            child: ExpansionTile(
              title: Text(dept.name),
              children: [
                for (final m in members.where((m) => m.departmentId == dept.id))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(m.userFullName),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Remove from department',
                      onPressed: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .removeMembership(m.id);
                        ref.invalidate(allMembershipsProvider);
                      },
                    ),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_add_alt_outlined),
                  title: const Text('Assign staff…'),
                  onTap: () => _showAssignDialog(
                    context,
                    ref,
                    dept.id,
                    staff.value ?? const [],
                    members
                        .where((m) => m.departmentId == dept.id)
                        .map((m) => m.userId)
                        .toSet(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showAssignDialog(
    BuildContext context,
    WidgetRef ref,
    String departmentId,
    List<StaffMember> allStaff,
    Set<String> alreadyIn,
  ) async {
    final candidates = [
      for (final s in allStaff)
        if (!alreadyIn.contains(s.id)) s,
    ];
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All staff are already in this department.')));
      return;
    }
    final selected = await showDialog<StaffMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign staff'),
        children: [
          for (final s in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(s.fullName),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await ref.read(adminRepositoryProvider).assignStaffToDepartment(
          departmentId: departmentId,
          userId: selected.id,
        );
    ref.invalidate(allMembershipsProvider);
  }
}
