import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/items_models.dart';
import '../data/items_providers.dart';

/// Create (item == null) or edit an item. Staff only — routing keeps
/// non-staff out, and RLS enforces it regardless.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.item});

  final Item? item;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.item?.name);
  late final _tagController =
      TextEditingController(text: widget.item?.distinguishingTag);
  late final _categoryController =
      TextEditingController(text: widget.item?.category);
  late String? _departmentId = widget.item?.owningDepartmentId;
  late bool _active = widget.item?.active ?? true;
  XFile? _photo;
  bool _submitting = false;
  String _nameQuery = '';

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    final repo = ref.read(itemsRepositoryProvider);
    try {
      String itemId;
      if (_isEdit) {
        itemId = widget.item!.id;
        await repo.updateItem(
          itemId,
          name: _nameController.text,
          distinguishingTag: _tagController.text,
          category: _categoryController.text,
          owningDepartmentId: _departmentId,
          active: _active,
        );
      } else {
        final created = await repo.createItem(
          name: _nameController.text,
          distinguishingTag: _tagController.text,
          category: _categoryController.text,
          owningDepartmentId: _departmentId,
        );
        itemId = created.id;
      }
      if (_photo != null) {
        await repo.uploadReferencePhoto(
          itemId,
          await _photo!.readAsBytes(),
          contentType: _photo!.mimeType ?? 'image/jpeg',
        );
      }
      ref.invalidate(itemsProvider);
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.code == '23505'
            ? 'An item with this name and tag already exists.'
            : 'Could not save: ${e.message}'),
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider).value ?? [];
    final myDeptIds = ref.watch(myDepartmentIdsProvider).value ?? {};
    // Staff may assign only departments they belong to; keep the current
    // assignment selectable when editing an item that already has one.
    final assignable = [
      for (final d in departments)
        if (myDeptIds.contains(d.id) || d.id == widget.item?.owningDepartmentId)
          d,
    ];
    final allItems = ref.watch(itemsProvider).value ?? [];
    final similar = _nameQuery.length < 2
        ? const <Item>[]
        : [
            for (final item in allItems)
              if (item.id != widget.item?.id &&
                  item.name.toLowerCase().contains(_nameQuery))
                item,
          ].take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Item' : 'New Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Multicab, Municipal Gymnasium',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) =>
                      setState(() => _nameQuery = v.trim().toLowerCase()),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Item name is required'
                      : null,
                ),
                if (similar.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Similar existing items — avoid duplicates:',
                              style: Theme.of(context).textTheme.labelMedium),
                          for (final item in similar)
                            Text('• ${item.displayName}'),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Distinguishing tag (optional)',
                    hintText: 'e.g. plate number, room number, unit letter',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional, free text)',
                    hintText: 'e.g. Vehicle, Venue, Equipment',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(
                    labelText: 'Owning department',
                    helperText:
                        'Unassigned items are managed by any LGU approver',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned (shared LGU pool)'),
                    ),
                    for (final d in assignable)
                      DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickPhoto,
                  icon: Icon(_photo == null
                      ? Icons.add_photo_alternate_outlined
                      : Icons.check_circle),
                  label: Text(_photo == null
                      ? (widget.item?.referencePhotoPath == null
                          ? 'Add reference photo (optional)'
                          : 'Replace reference photo')
                      : 'Photo selected'),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _active,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _active = v),
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Inactive items stay in history but cannot be borrowed'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _save,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Create item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
