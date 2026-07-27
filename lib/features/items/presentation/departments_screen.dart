import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/glossy_background.dart';
import '../data/items_models.dart';
import '../data/items_providers.dart';
import '../data/items_repository.dart';

/// Staff-only department management: rename, deactivate/reactivate, and
/// delete (when nothing references it) — everything the item form's
/// department dropdown needs but couldn't do inline.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(allDepartmentsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDepartment(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add department'),
      ),
      body: GlossyBackground(
        child: switch (departments) {
          AsyncData(:final value) => value.isEmpty
              ? const Center(child: Text('No departments yet.'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: value.length,
                      itemBuilder: (context, i) =>
                          _DepartmentTile(department: value[i]),
                    ),
                  ),
                ),
          AsyncError(:final error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load departments.\n$error'),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(department.name),
        subtitle: department.active
            ? null
            : Text(
                'Deactivated — hidden from new item assignments',
                style: TextStyle(color: scheme.error),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, ref),
            ),
            Switch(
              value: department.active,
              onChanged: (v) => _setActive(context, ref, v),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
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
