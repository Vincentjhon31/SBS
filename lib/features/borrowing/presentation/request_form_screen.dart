import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../items/data/items_models.dart';
import '../../items/data/items_providers.dart';
import '../data/borrow_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({super.key, this.preselectedItem});

  /// Item chosen before landing on this form (e.g. tapped from Home's
  /// "Available to Borrow" grid). The `requestNew` route works fine
  /// without it too — the existing "New request" FAB doesn't pass one.
  final Item? preselectedItem;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

/// Whether the borrower collects the item on the event's first day, or a
/// day earlier (the DB caps advance pickup at exactly one day).
enum _PickupWhen { sameDay, dayBefore }

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _itemController = TextEditingController(
    text: widget.preselectedItem?.displayName,
  );
  final _purposeController = TextEditingController();
  late Item? _selectedItem = widget.preselectedItem;

  // The event/use window the borrower actually needs the item for.
  DateTime? _useFrom;
  DateTime? _useTo;
  // Pickup choice (relative to _useFrom) and the return date/time.
  _PickupWhen _pickupWhen = _PickupWhen.sameDay;
  DateTime? _return;
  bool _submitting = false;

  /// Derived availability start: pickup is the use-start, or the calendar
  /// day before it (keeping the same time-of-day).
  DateTime? get _pickup {
    if (_useFrom == null) return null;
    return _pickupWhen == _PickupWhen.dayBefore
        ? _useFrom!.subtract(const Duration(days: 1))
        : _useFrom!;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial, DateTime first) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Booking must be at least one day ahead so staff can review before
  /// pickup — so the earliest selectable use-start is tomorrow.
  DateTime get _earliestUse {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day);
  }

  Future<void> _pickUseFrom() async {
    final picked = await _pickDateTime(_useFrom ?? _earliestUse, _earliestUse);
    if (picked == null) return;
    setState(() {
      _useFrom = picked;
      // Keep use-end and return consistent with the new start.
      if (_useTo == null || _useTo!.isBefore(picked)) _useTo = picked;
      if (_return == null || _return!.isBefore(_useTo!)) _return = _useTo;
    });
  }

  Future<void> _pickUseTo() async {
    if (_useFrom == null) return;
    final picked = await _pickDateTime(_useTo ?? _useFrom!, _useFrom!);
    if (picked == null) return;
    setState(() {
      _useTo = picked;
      if (_return == null || _return!.isBefore(picked)) _return = picked;
    });
  }

  Future<void> _pickReturn() async {
    if (_useTo == null) return;
    final picked = await _pickDateTime(_return ?? _useTo!, _useTo!);
    if (picked == null) return;
    setState(() => _return = picked);
  }

  /// Resolves the item to request: the picked suggestion, an existing item
  /// whose name matches the typed text exactly (case-insensitive — covers
  /// "didn't click the suggestion but typed the same name"), or a brand
  /// new item created on the spot (confirmed first, since this permanently
  /// adds to the shared registry).
  Future<Item?> _resolveItem(List<Item> activeItems) async {
    if (_selectedItem != null) return _selectedItem;

    final typed = _itemController.text.trim();
    if (typed.isEmpty) return null;

    for (final item in activeItems) {
      if (item.displayName.toLowerCase() == typed.toLowerCase()) {
        return item;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a new item?'),
        content: Text(
          '"$typed" isn\'t in the catalog yet. Add it and request it — '
          'staff will review it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add & request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return null;

    return ref.read(itemsRepositoryProvider).createItem(name: typed);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    final activeItems = [
      for (final item in ref.read(itemsProvider).value ?? const <Item>[])
        if (item.active) item,
    ];
    final item = await _resolveItem(activeItems);
    if (item == null) {
      if (_selectedItem == null && _itemController.text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter the item you want to borrow.')),
        );
      }
      return;
    }
    if (_useFrom == null || _useTo == null || _return == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pick when you will use it and return it.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(borrowRepositoryProvider)
          .createRequest(
            itemId: item.id,
            from: _pickup!,
            to: _return!,
            useFrom: _useFrom,
            useTo: _useTo,
            purpose: _purposeController.text,
          );
      ref.invalidate(myRequestsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Request submitted — awaiting approval.')),
      );
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit: ${e.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not submit. Check your connection.'),
        ),
      );
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
    // Conflict is checked against the availability window (pickup → return),
    // since that's what actually reserves the item — and, for a
    // multi-unit item, only once overlapping reservations would already
    // fill every unit (the server has the final say either way; this is
    // just an early warning).
    final overlappingCount = _pickup == null || _return == null
        ? 0
        : windows?.where((w) => w.overlaps(_pickup!, _return!)).length ?? 0;
    final hasConflict =
        _pickup != null &&
        _return != null &&
        overlappingCount >= (_selectedItem?.quantity ?? 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Request an Item')),
      body: GlossyBackground(
        child: SafeArea(
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
                      return activeItems.where(
                        (item) => item.displayName.toLowerCase().contains(q),
                      );
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
                                helperText: 'Not in the list? Type the '
                                    'item\'s name — staff will review it.',
                                helperMaxLines: 2,
                                suffixIcon: _selectedItem != null
                                    ? const Icon(Icons.check_circle)
                                    : const Icon(Icons.search),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter the item you want to borrow'
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
                  Text(
                    'When will you use it?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(
                            _useFrom == null
                                ? 'Use from…'
                                : 'Use from: ${_format(_useFrom!)}',
                          ),
                          subtitle: const Text(
                            'Bookings must be at least a day ahead',
                          ),
                          onTap: _submitting ? null : _pickUseFrom,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.event_repeat),
                          title: Text(
                            _useTo == null
                                ? 'Use until…'
                                : 'Use until: ${_format(_useTo!)}',
                          ),
                          subtitle: const Text('Same day for a one-day event'),
                          enabled: !_submitting && _useFrom != null,
                          onTap: _submitting || _useFrom == null
                              ? null
                              : _pickUseTo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pick up',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<_PickupWhen>(
                            segments: const [
                              ButtonSegment(
                                value: _PickupWhen.sameDay,
                                icon: Icon(Icons.today),
                                label: Text('On the day'),
                              ),
                              ButtonSegment(
                                value: _PickupWhen.dayBefore,
                                icon: Icon(Icons.history),
                                label: Text('1 day before'),
                              ),
                            ],
                            selected: {_pickupWhen},
                            onSelectionChanged: _submitting || _useFrom == null
                                ? null
                                : (s) => setState(() => _pickupWhen = s.first),
                          ),
                          if (_pickup != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Pick up on ${_format(_pickup!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Return', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text(
                        _return == null
                            ? 'Return by…'
                            : 'Return by: ${_format(_return!)}',
                      ),
                      subtitle: const Text('Defaults to your last use day'),
                      enabled: !_submitting && _useTo != null,
                      onTap: _submitting || _useTo == null ? null : _pickReturn,
                    ),
                  ),
                  if (hasConflict) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
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
      ),
    );
  }

  static String _format(DateTime dt) => formatDateTime(dt);
}
