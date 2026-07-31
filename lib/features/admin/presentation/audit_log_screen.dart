import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/glossy_background.dart';
import '../data/admin_models.dart';
import '../data/admin_providers.dart';

const _actionLabels = <String, String>{
  'citizen_verified': 'Verified citizen ID',
  'citizen_unverified': 'Un-verified citizen ID',
  'set_user_type': 'Changed account role',
  'superadmin_granted': 'Granted superadmin',
  'superadmin_revoked': 'Revoked superadmin',
  'account_deactivated': 'Deactivated account',
  'account_reactivated': 'Reactivated account',
  'broadcast_announcement': 'Sent a broadcast announcement',
  'set_app_setting': 'Edited a system setting',
};

/// Read-only accountability trail — every sensitive Users/Settings action
/// writes here via the log_audit() SQL helper, which the client can never
/// call directly (see the users_management migration).
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditLogProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Activity Log')),
      body: GlossyBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (entries) {
              AsyncData(:final value) => value.isEmpty
                  ? const Center(child: Text('No activity recorded yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: value.length,
                      itemBuilder: (context, i) => _EntryTile(entry: value[i]),
                    ),
              AsyncError(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load the activity log.\n$error'),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(_actionLabels[entry.action] ?? entry.action),
        subtitle: Text(
          '${entry.actorName ?? 'Unknown staff'} • ${formatRelative(entry.createdAt)}',
        ),
      ),
    );
  }
}
