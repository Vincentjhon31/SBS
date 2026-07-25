import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/request_status_chip.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';

String _shortDate(DateTime d) => formatDayMonth(d);

String _relativeTime(DateTime dt) => formatRelative(dt);

/// Full oversight bundle: cross-department stats, a request/activity
/// overview, department/staff assignment, and shortcuts to things that
/// are already staff-wide (Approvals now shows every department to a
/// superadmin via RLS; the deletion queue lives in Settings).
///
/// Reached only from the web sidebar (staff never see this on mobile —
/// see app_shell.dart), so the layout leans into desktop width: KPI
/// bands, charts, and a two-column body all reflow with the window,
/// falling back to a single column if the browser window is narrow.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperadmin = ref.watch(isSuperadminProvider);

    // Lives inside the staff web shell (a sidebar branch), which already
    // provides the page title in its header bar — no AppBar needed.
    if (!isSuperadmin) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Not authorized.')),
      );
    }

    final stats = ref.watch(superadminStatsProvider);
    final trends = ref.watch(superadminTrendsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superadminStatsProvider);
          ref.invalidate(superadminTrendsProvider);
          ref.invalidate(allMembershipsProvider);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                switch (stats) {
                  AsyncData(:final value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AttentionBand(stats: value),
                      const SizedBox(height: 20),
                      _InventoryGrid(stats: value),
                    ],
                  ),
                  AsyncError() => const Text('Could not load stats.'),
                  _ => const Center(child: CircularProgressIndicator()),
                },
                const SizedBox(height: 32),
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                switch (trends) {
                  AsyncData(:final value) => Column(
                    children: [
                      _TwoColumnRow(
                        left: _TrendChartCard(daily: value.dailyRequests),
                        right: _StatusBreakdownCard(
                          byStatus: value.requestsByStatus,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TwoColumnRow(
                        left: _TopCategoriesCard(
                          categories: value.topCategories,
                        ),
                        right: _RecentActivityCard(
                          activity: value.recentActivity,
                        ),
                      ),
                    ],
                  ),
                  AsyncError() => const Text('Could not load activity data.'),
                  _ => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final departments = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Departments & Staff',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const _DepartmentsPanel(),
                      ],
                    );
                    final shortcuts = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shortcuts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const _ShortcutsCard(),
                      ],
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          departments,
                          const SizedBox(height: 24),
                          shortcuts,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: departments),
                        const SizedBox(width: 24),
                        Expanded(child: shortcuts),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacks two cards on narrow windows, sits them side by side (equal
/// width) once there's room — used to pair up the new activity charts.
class _TwoColumnRow extends StatelessWidget {
  const _TwoColumnRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

/// The four numbers that actually need someone to act on them today,
/// pulled out of the plain inventory grid and given more visual weight.
class _AttentionBand extends StatelessWidget {
  const _AttentionBand({required this.stats});

  final SuperadminStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cards = [
      _AttentionCard(
        label: 'Pending requests',
        value: stats.pendingRequests,
        icon: Icons.hourglass_top,
        color: scheme.tertiary,
      ),
      _AttentionCard(
        label: 'Active loans',
        value: stats.activeLoans,
        icon: Icons.outbound,
        color: scheme.primary,
      ),
      _AttentionCard(
        label: 'Overdue',
        value: stats.overdueRequests,
        icon: Icons.warning_amber,
        color: scheme.error,
        urgent: stats.overdueRequests > 0,
      ),
      _AttentionCard(
        label: 'Deletion requests',
        value: stats.pendingDeletionRequests,
        icon: Icons.person_remove_outlined,
        color: scheme.secondary,
      ),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [for (final c in cards) SizedBox(width: 250, child: c)],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.urgent = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgent ? scheme.errorContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The steadier, registry-composition numbers — still worth seeing, but
/// nothing here needs same-day action.
class _InventoryGrid extends StatelessWidget {
  const _InventoryGrid({required this.stats});

  final SuperadminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Items', stats.totalItems, Icons.inventory_2_outlined),
      ('Departments', stats.totalDepartments, Icons.apartment_outlined),
      ('Staff', stats.totalStaff, Icons.badge_outlined),
      ('Citizens', stats.totalCitizens, Icons.people_outline),
      (
        'Verified citizens',
        stats.verifiedCitizens,
        Icons.verified_user_outlined,
      ),
      (
        'Unverified citizens',
        stats.unverifiedCitizens,
        Icons.gpp_maybe_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 6);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final (label, value, icon) in tiles)
              _StatTile(label, value, icon),
          ],
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Shared card chrome for the activity section — a title, an optional
/// muted subtitle (used for empty-state context), then the chart/list.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.daily});

  final List<DailyRequestCount> daily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = daily.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final ceiling = maxCount == 0 ? 4.0 : (maxCount * 1.3).ceilToDouble();
    final spots = [
      for (final (i, d) in daily.indexed)
        FlSpot(i.toDouble(), d.count.toDouble()),
    ];
    final bodySmall = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return _ChartCard(
      title: 'Requests — last 14 days',
      subtitle: maxCount == 0 ? 'No requests in this window yet.' : null,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: ceiling,
            minX: 0,
            maxX: (daily.length - 1).toDouble(),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: ceiling / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: ceiling / 2,
                  getTitlesWidget: (value, meta) =>
                      Text('${value.toInt()}', style: bodySmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 3,
                  // maxIncluded would force a label at index 13 as well,
                  // crowding it right next to the interval-3 label at 12.
                  maxIncluded: false,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= daily.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_shortDate(daily[i].day), style: bodySmall),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                  final d = daily[s.x.toInt()];
                  return LineTooltipItem(
                    '${d.count} request${d.count == 1 ? '' : 's'}\n${_shortDate(d.day)}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: scheme.primary,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ranked bar per entry: icon (optional) + label + proportional bar
/// + value, all directly labeled so identity never depends on color
/// alone. Shared by the status breakdown and the top-categories chart.
class _BarEntry {
  const _BarEntry({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData? icon;
}

class _RankedBarList extends StatelessWidget {
  const _RankedBarList({required this.entries});

  final List<_BarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    return Column(
      children: [
        for (final e in entries) ...[
          Row(
            children: [
              if (e.icon != null) ...[
                Icon(
                  e.icon,
                  size: 16,
                  color: e.value == 0 ? scheme.onSurfaceVariant : e.color,
                ),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 84,
                child: Text(
                  e.label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (e.value / maxValue).clamp(0, 1),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: e.value == 0
                                ? scheme.surfaceContainerHighest
                                : e.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.byStatus});

  final List<StatusCount> byStatus;

  static const _meta = <String, (String, IconData)>{
    'pending': ('Pending', Icons.hourglass_top),
    'approved': ('Approved', Icons.thumb_up_outlined),
    'released': ('Released', Icons.outbound),
    'returned': ('Returned', Icons.assignment_turned_in_outlined),
    'closed': ('Closed', Icons.task_alt),
    'rejected': ('Rejected', Icons.block),
    'overdue': ('Overdue', Icons.warning_amber),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color colorFor(String status) => switch (status) {
      'pending' => scheme.tertiary,
      'approved' => scheme.primary,
      'released' => scheme.secondary,
      'returned' || 'closed' => scheme.outline,
      'rejected' => scheme.error.withValues(alpha: 0.7),
      'overdue' => scheme.error,
      _ => scheme.outline,
    };
    return _ChartCard(
      title: 'Requests by status',
      child: _RankedBarList(
        entries: [
          for (final s in byStatus)
            _BarEntry(
              label: _meta[s.status]?.$1 ?? s.status,
              value: s.count,
              color: colorFor(s.status),
              icon: _meta[s.status]?.$2,
            ),
        ],
      ),
    );
  }
}

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.categories});

  final List<CategoryCount> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return _ChartCard(
        title: 'Top categories by requests',
        child: Text(
          'No requests yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return _ChartCard(
      title: 'Top categories by requests',
      child: _RankedBarList(
        entries: [
          for (final c in categories)
            _BarEntry(label: c.category, value: c.count, color: scheme.primary),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activity});

  final List<RecentActivityItem> activity;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return _ChartCard(
        title: 'Recent activity',
        child: Text(
          'No requests yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return _ChartCard(
      title: 'Recent activity',
      child: Column(
        children: [
          for (final a in activity) ...[
            _ActivityRow(item: a),
            if (a != activity.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final RecentActivityItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(
            item.isGuest ? Icons.badge_outlined : Icons.account_circle_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.borrowerName}${item.isGuest ? ' · walk-in' : ''} · '
                '${_relativeTime(item.createdAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        RequestStatusChip(status: item.status),
      ],
    );
  }
}

class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.approval_outlined),
            title: const Text('All Approvals'),
            subtitle: const Text(
              'You see every department\'s requests here now',
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All staff are already in this department.'),
        ),
      );
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
    await ref
        .read(adminRepositoryProvider)
        .assignStaffToDepartment(
          departmentId: departmentId,
          userId: selected.id,
        );
    ref.invalidate(allMembershipsProvider);
  }
}
