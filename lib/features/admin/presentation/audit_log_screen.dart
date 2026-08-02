import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';
import 'admin_page.dart';

/// How each recorded action is presented: a readable label, an icon, and
/// a hue. Anything not listed still renders, using its raw action name.
const _actionInfo = <String, (String, IconData, Color)>{
  'citizen_verified': (
    'Verified a citizen ID',
    Icons.verified_user_outlined,
    Color(0xFF1F9D65),
  ),
  'citizen_unverified': (
    'Removed ID verification',
    Icons.gpp_maybe_outlined,
    Color(0xFFE07A1F),
  ),
  'set_user_type': (
    'Changed an account role',
    Icons.swap_vert,
    Color(0xFF2B7FFF),
  ),
  'superadmin_granted': (
    'Granted superadmin',
    Icons.shield_outlined,
    Color(0xFF6750A4),
  ),
  'superadmin_revoked': (
    'Revoked superadmin',
    Icons.shield_outlined,
    Color(0xFFE07A1F),
  ),
  'account_deactivated': ('Deactivated an account', Icons.block, Color(0xFFD32F2F)),
  'account_reactivated': (
    'Reactivated an account',
    Icons.check_circle_outline,
    Color(0xFF1F9D65),
  ),
  'broadcast_announcement': (
    'Sent a broadcast announcement',
    Icons.campaign_outlined,
    Color(0xFFC2185B),
  ),
  'set_app_setting': (
    'Edited a system setting',
    Icons.settings_suggest_outlined,
    Color(0xFF8D6E63),
  ),
};

/// Read-only accountability trail. Every sensitive action writes here
/// through the log_audit() SQL helper, which the client cannot call
/// directly — so entries cannot be forged or edited from the app.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditLogProvider);
    final all = entries.value ?? const <AuditLogEntry>[];
    final filtered = _query.isEmpty
        ? all
        : all.where((e) {
            final label = _actionInfo[e.action]?.$1 ?? e.action;
            return label.toLowerCase().contains(_query) ||
                (e.actorName?.toLowerCase().contains(_query) ?? false);
          }).toList();

    return AdminPage(
      icon: Icons.history,
      title: 'Activity Log',
      subtitle: 'Who changed what, and when — newest first.',
      accent: const Color(0xFF5C6BC0),
      maxWidth: 820,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(auditLogProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      toolbar: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Filter by action or staff name…',
        ),
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      ),
      child: switch (entries) {
        AsyncError(:final error) => AdminEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load the activity log',
          hint: '$error',
        ),
        _ when all.isEmpty && entries.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when all.isEmpty => const AdminEmptyState(
          icon: Icons.history_toggle_off,
          title: 'No activity recorded yet',
          hint: 'Verifications, role changes, and announcements will be '
              'listed here as staff perform them.',
        ),
        _ when filtered.isEmpty => const AdminEmptyState(
          icon: Icons.search_off,
          title: 'No entries match',
          hint: 'Try a different action or staff name.',
        ),
        _ => RefreshIndicator(
          onRefresh: () async => ref.invalidate(auditLogProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _EntryRow(
              entry: filtered[i],
              // The connecting rule is dropped on the last row so the
              // timeline terminates instead of trailing into the padding.
              isLast: i == filtered.length - 1,
            ).fadeUpAt(i),
          ),
        ),
      },
    );
  }
}

/// One timeline row: a coloured action marker on a vertical rule, with
/// the actor and relative time beside it.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isLast});

  final AuditLogEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info =
        _actionInfo[entry.action] ??
        (entry.action, Icons.bolt_outlined, scheme.primary);
    final detail = entry.detail.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: info.$3.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(info.$2, size: 18, color: info.$3),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.$1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.actorName ?? 'Unknown staff'} · '
                    '${formatRelative(entry.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        detail,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
