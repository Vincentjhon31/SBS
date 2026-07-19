import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../items/data/items_models.dart';
import '../../items/data/items_providers.dart';
import '../data/borrow_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({super.key});

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _purposeController = TextEditingController();
  Item? _selectedItem;
  DateTime? _from;
  DateTime? _to;
  bool _submitting = false;

  @override
  void dispose() {
    _itemController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_from ?? now) : (_to ?? _from ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && !_to!.isAfter(picked)) _to = null;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Select an item from the list.')));
      return;
    }
    if (_from == null || _to == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Pick the borrow and return dates.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(borrowRepositoryProvider).createRequest(
            itemId: _selectedItem!.id,
            from: _from!,
            to: _to!,
            purpose: _purposeController.text,
          );
      ref.invalidate(myRequestsProvider);
      messenger.showSnackBar(const SnackBar(
          content: Text('Request submitted — awaiting approval.')));
      if (mounted) context.go(AppRoutes.requests);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not submit: ${e.message}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not submit. Check your connection.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider).value ?? [];
    final activeItems = [
      for (final item in items)
        if (item.active) item,
    ];

    final windows = _selectedItem == null
        ? null
        : ref.watch(reservedWindowsProvider(_selectedItem!.id)).value;
    final hasConflict = _from != null &&
        _to != null &&
        (windows?.any((w) => w.overlaps(_from!, _to!)) ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request an Item'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RawAutocomplete<Item>(
                  textEditingController: _itemController,
                  focusNode: FocusNode(),
                  displayStringForOption: (item) => item.displayName,
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return activeItems;
                    return activeItems.where((item) =>
                        item.displayName.toLowerCase().contains(q));
                  },
                  onSelected: (item) => setState(() => _selectedItem = item),
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmit) =>
                          TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Item',
                      hintText: 'Start typing — e.g. Multicab',
                      suffixIcon: _selectedItem != null
                          ? const Icon(Icons.check_circle)
                          : const Icon(Icons.search),
                    ),
                    validator: (v) => _selectedItem == null
                        ? 'Pick an item from the suggestions'
                        : null,
                    onChanged: (v) {
                      if (_selectedItem != null &&
                          v != _selectedItem!.displayName) {
                        setState(() => _selectedItem = null);
                      }
                    },
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final option in options)
                              ListTile(
                                title: Text(option.displayName),
                                subtitle: option.category == null
                                    ? null
                                    : Text(option.category!),
                                onTap: () => onSelected(option),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(_from == null
                      ? 'Borrow from…'
                      : 'From: ${_format(_from!)}'),
                  onTap: _submitting ? null : () => _pickDateTime(isFrom: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available),
                  title: Text(
                      _to == null ? 'Return by…' : 'Until: ${_format(_to!)}'),
                  onTap: _submitting || _from == null
                      ? null
                      : () => _pickDateTime(isFrom: false),
                ),
                if (hasConflict) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'This item already has an approved reservation '
                              'overlapping your dates. You can still submit, '
                              'but approval is unlikely for this window.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose',
                    hintText: 'What will it be used for?',
                  ),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Purpose is required'
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit request'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Every request needs approval by LGU staff before release.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(DateTime dt) {
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
