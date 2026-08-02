import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_animations.dart';
import '../../admin/presentation/admin_page.dart';
import '../data/items_models.dart';
import '../data/items_providers.dart';
import '../data/items_repository.dart';

const _accent = Color(0xFF0E8C8B);

/// Staff-only department management: rename, deactivate/reactivate, and
/// delete (when nothing references it) — everything the item form's
/// department dropdown needs but couldn't do inline.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(allDepartmentsProvider);
    return AdminPage(
      icon: Icons.apartment_outlined,
      title: 'Departments',
      subtitle: 'Offices that own items and approve requests for them.',
      accent: _accent,
      maxWidth: 720,
      actions: [
        FilledButton.icon(
          onPressed: () => _addDepartment(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
      child: switch (departments) {
        AsyncData(:final value) when value.isEmpty => AdminEmptyState(
          icon: Icons.apartment_outlined,
          title: 'No departments yet',
          hint: 'Add the offices that lend items out, then assign staff to '
              'them from the dashboard.',
          action: FilledButton.icon(
            onPressed: () => _addDepartment(context, ref),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add department'),
          ),
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(allDepartmentsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: value.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DepartmentTile(department: value[i]),
            ).fadeUpAt(i),
          ),
        ),
        AsyncError(:final error) => AdminEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load departments',
          hint: '$error',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _addDepartment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New department'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Motor Pool'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(itemsRepositoryProvider).createDepartment(trimmed);
      ref.invalidate(allDepartmentsProvider);
      ref.invalidate(departmentsProvider);
      // The RPC enrolls the caller as the new department's first approver,
      // so the item form's (membership-scoped) dropdown needs this too.
      ref.invalidate(myDepartmentIdsProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == '23505'
                ? 'A department with this name already exists.'
                : 'Could not add: ${e.message}',
          ),
        ),
      );
    }
  }
}

class _DepartmentTile extends ConsumerWidget {
  const _DepartmentTile({required this.department});

  final Department department;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: department.active
                  ? _accent.withValues(alpha: 0.13)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.apartment_outlined,
              size: 21,
              color: department.active ? _accent : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  department.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  department.active
                      ? 'Assignable to items'
                      : 'Deactivated — hidden from new item assignments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: department.active
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: department.active,
            onChanged: (v) => _setActive(context, ref, v),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) => v == 'rename'
                ? _rename(context, ref)
                : _delete(context, ref),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: scheme.error),
                    const SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: scheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: department.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename department'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == department.name ||
        !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(itemsRepositoryProvider).renameDepartment(department.id, trimmed);
      ref.invalidate(allDepartmentsProvider);
      ref.invalidate(departmentsProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not rename: ${e.message}')));
    }
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool active) async {
    await ref.read(itemsRepositoryProvider).setDepartmentActive(department.id, active);
    ref.invalidate(allDepartmentsProvider);
    ref.invalidate(departmentsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text(
          'Permanently delete "${department.name}"? This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(itemsRepositoryProvider);
    try {
      await repo.deleteDepartment(department.id);
      ref.invalidate(allDepartmentsProvider);
      ref.invalidate(departmentsProvider);
      messenger.showSnackBar(SnackBar(content: Text('Deleted "${department.name}".')));
    } on PostgrestException catch (e) {
      final blocked = e.hint == 'deactivate' ||
          e.message.contains('items assigned') ||
          e.message.contains('staff members');
      if (blocked && context.mounted) {
        await _offerDeactivate(context, repo, messenger);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Could not delete: ${e.message}')));
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete. Check your connection.')),
      );
    }
  }

  Future<void> _offerDeactivate(
    BuildContext context,
    ItemsRepository repo,
    ScaffoldMessengerState messenger,
  ) async {
    final deactivate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Can\'t delete'),
        content: Text(
          '"${department.name}" still has items or staff assigned to it, '
          'so it can\'t be permanently deleted. Deactivate it instead? '
          'It will stay in history but won\'t be assignable to new items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (deactivate != true || !context.mounted) return;
    await repo.setDepartmentActive(department.id, false);
    messenger.showSnackBar(SnackBar(content: Text('Deactivated "${department.name}".')));
  }
}
