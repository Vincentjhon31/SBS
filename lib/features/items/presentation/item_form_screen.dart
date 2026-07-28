import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/full_image_viewer.dart';
import '../../../core/widgets/glossy_background.dart';
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
  late final _tagController = TextEditingController(
    text: widget.item?.distinguishingTag,
  );
  late String? _category = widget.item?.category?.trim().isEmpty ?? true
      ? null
      : widget.item?.category;
  late String? _departmentId = widget.item?.owningDepartmentId;
  late bool _active = widget.item?.active ?? true;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _submitting = false;
  String _nameQuery = '';

  bool get _isEdit => widget.item != null;

  List<String> _existingCategories(List<Item> items) {
    final set = {
      for (final item in items)
        if (item.category != null && item.category!.trim().isNotEmpty)
          item.category!.trim(),
    };
    final list = set.toList()..sort();
    return list;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
    });
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
          category: _category,
          owningDepartmentId: _departmentId,
          active: _active,
        );
      } else {
        final created = await repo.createItem(
          name: _nameController.text,
          distinguishingTag: _tagController.text,
          category: _category,
          owningDepartmentId: _departmentId,
        );
        itemId = created.id;
      }
      if (_photo != null && _photoBytes != null) {
        await repo.uploadReferencePhoto(
          itemId,
          _photoBytes!,
          contentType: _photo!.mimeType ?? 'image/jpeg',
        );
      }
      ref.invalidate(itemsProvider);
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == '23505'
                ? 'An item with this name and tag already exists.'
                : 'Could not save: ${e.message}',
          ),
        ),
      );
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Item' : 'New Item')),
      body: GlossyBackground(
        child: SafeArea(
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Similar existing items — avoid duplicates:',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
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
                  _CategoryDropdown(
                    value: _category,
                    existing: _existingCategories(allItems),
                    onChanged: (v) => setState(() => _category = v),
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
                        DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                  const SizedBox(height: 16),
                  _PhotoPreview(
                    photoBytes: _photoBytes,
                    existingPath: widget.item?.referencePhotoPath,
                  ),
                  if (_photoBytes != null || widget.item?.referencePhotoPath != null)
                    const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickPhoto,
                    icon: Icon(
                      _photo == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(
                      _photo == null
                          ? (widget.item?.referencePhotoPath == null
                                ? 'Add reference photo (optional)'
                                : 'Replace reference photo')
                          : 'Photo selected',
                    ),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        value: _active,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _active = v),
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Inactive items stay in history but cannot be borrowed',
                        ),
                      ),
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
      ),
    );
  }
}

/// Shows the freshly picked photo (from bytes, no round-trip needed), else
/// the item's existing reference photo (signed URL) when editing, else
/// nothing — so staff can see what's actually on file instead of a bare
/// "Replace reference photo" button with no way to check the current one.
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.photoBytes, required this.existingPath});

  final Uint8List? photoBytes;
  final String? existingPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          photoBytes!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    if (existingPath == null) return const SizedBox.shrink();
    final url = ref.watch(itemPhotoUrlProvider(existingPath!));
    return switch (url) {
      AsyncData(:final value) => GestureDetector(
        onTap: () => showFullImage(context, value),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            value,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, e, s) => Container(
              height: 160,
              alignment: Alignment.center,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
      AsyncError() => const SizedBox.shrink(),
      _ => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

const _addNewCategoryValue = '__add_new__';

/// A dropdown of every category already in use, color-coded to match the
/// badges shown elsewhere, plus an "Add new category" entry that opens a
/// small dialog — keeps the registry's "just type it" growth model while
/// steering staff toward reusing an existing category instead of creating
/// near-duplicates ("Vehicle" vs "Vehicles") by accident.
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.existing,
    required this.onChanged,
  });

  final String? value;
  final List<String> existing;
  final ValueChanged<String?> onChanged;

  Future<void> _addNew(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Vehicle, Venue'),
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
    final trimmed = result?.trim();
    if (trimmed != null && trimmed.isNotEmpty) onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    // The current value might be a brand-new category not yet in
    // `existing` (freshly added, or set on an item being edited) — make
    // sure it's still a valid dropdown entry so it doesn't get dropped.
    final options = {...existing, ?value}.toList()..sort();
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Category (optional)',
        helperText: 'Pick an existing category or add a new one',
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None')),
        for (final category in options)
          DropdownMenuItem(value: category, child: Text(category)),
        const DropdownMenuItem(
          value: _addNewCategoryValue,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 6),
              Text('Add new category…'),
            ],
          ),
        ),
      ],
      onChanged: (v) {
        if (v == _addNewCategoryValue) {
          _addNew(context);
        } else {
          onChanged(v);
        }
      },
    );
  }
}
