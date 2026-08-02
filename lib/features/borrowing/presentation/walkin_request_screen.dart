import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/workbench_scaffold.dart';
import '../../approvals/data/approvals_models.dart';
import '../../approvals/data/approvals_providers.dart';
import '../../items/data/items_models.dart';
import '../../items/data/items_providers.dart';
import '../data/borrow_providers.dart';

/// Staff-only counter flow for someone with no app account: fill in who
/// they are, what they're borrowing, and when — then go straight into
/// evidence capture (photos + liability ack) for the handoff, same as any
/// other release.
class WalkInRequestScreen extends ConsumerStatefulWidget {
  const WalkInRequestScreen({super.key});

  @override
  ConsumerState<WalkInRequestScreen> createState() =>
      _WalkInRequestScreenState();
}

class _WalkInRequestScreenState extends ConsumerState<WalkInRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  Item? _selectedItem;
  DateTime _from = DateTime.now();
  DateTime? _to;
  bool _notSureWhenReturning = false;
  bool _consented = false;
  bool _submitting = false;

  /// Units being handed over. Only surfaced for items with more than one,
  /// and clamped to the item's total at submit — picking a different item
  /// after raising this could otherwise send an impossible count.
  int _quantity = 1;

  @override
  void dispose() {
    _itemController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? _from : (_to ?? _from);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
        const SnackBar(content: Text('Select an item from the list.')),
      );
      return;
    }
    if (!_notSureWhenReturning && _to == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pick a return date, or check "Not sure when returning."',
          ),
        ),
      );
      return;
    }
    if (!_consented) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Read the notice to the guest and confirm their consent.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final requestId = await ref
          .read(borrowRepositoryProvider)
          .createGuestRequest(
            itemId: _selectedItem!.id,
            fullName: _nameController.text,
            address: _addressController.text,
            contactNumber: _contactController.text,
            email: _emailController.text,
            purpose: _purposeController.text,
            from: _from,
            to: _notSureWhenReturning ? null : _to,
            consented: true,
            quantity: _quantity.clamp(1, _selectedItem!.quantity),
          );
      ref.invalidate(approvalQueueProvider);
      if (!mounted) return;
      // Straight into the same release-evidence flow every other handoff
      // uses — replace this form in the stack so "back" from there
      // returns to Approvals, not to a stale filled-out form.
      context.pushReplacement(
        AppRoutes.evidenceCapture,
        extra: EvidenceCaptureArgs(
          stage: 'release',
          request: PendingApproval(
            id: requestId,
            itemLabel: _selectedItem!.displayName,
            purpose: _purposeController.text.trim(),
            requestedFrom: _from,
            requestedTo: _notSureWhenReturning ? null : _to,
            borrowerId: null,
            borrowerName: _nameController.text.trim(),
            borrowerType: 'guest',
            status: 'approved',
            createdAt: DateTime.now(),
          ),
        ),
      );
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create walk-in: ${e.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not create walk-in. Check your connection.'),
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

    final scheme = Theme.of(context).colorScheme;
    final maxUnits = _selectedItem?.quantity ?? 1;

    return Form(
      key: _formKey,
      child: WorkbenchScaffold(
        title: 'Walk-in Request',
        subtitle: 'Counter loan witnessed by staff',
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkbenchCard(
              title: 'Borrower details',
              icon: Icons.badge_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Full name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '09XX XXX XXXX',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 7)
                        ? 'Contact number is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            WorkbenchCard(
              title: 'What are they borrowing?',
              icon: Icons.inventory_2_outlined,
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
                        (i) => i.displayName.toLowerCase().contains(q),
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
                                  onTap: () => onSelected(option),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Walk-ins used to be silently fixed at one unit, so a
                  // counter loan of 25 chairs looked identical to a loan
                  // of one and the capacity check under-counted it.
                  if (maxUnits > 1) ...[
                    const SizedBox(height: 18),
                    _WalkInQuantity(
                      value: _quantity.clamp(1, maxUnits),
                      max: maxUnits,
                      enabled: !_submitting,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _purposeController,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      hintText: 'What will it be used for?',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Purpose is required'
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        side: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkbenchCard(
              title: 'Loan window',
              icon: Icons.event_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateRow(
                    icon: Icons.event,
                    label: 'BORROW FROM',
                    value: _format(_from),
                    onTap: _submitting
                        ? null
                        : () => _pickDateTime(isFrom: true),
                  ),
                  const SizedBox(height: 10),
                  _DateRow(
                    icon: Icons.event_available,
                    label: 'RETURN BY',
                    value: _to == null
                        ? (_notSureWhenReturning ? 'Open-ended' : 'Not set')
                        : _format(_to!),
                    onTap: _submitting || _notSureWhenReturning
                        ? null
                        : () => _pickDateTime(isFrom: false),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _notSureWhenReturning,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() {
                            _notSureWhenReturning = v ?? false;
                            if (_notSureWhenReturning) _to = null;
                          }),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: const Text('Not sure when returning'),
                    subtitle: const Text(
                      'Stays reserved until marked returned',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            WorkbenchCard(
              title: 'Data privacy notice',
              icon: Icons.privacy_tip_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConstants.guestConsentStatement,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _submitting
                        ? null
                        : () => setState(() => _consented = !_consented),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _consented
                            ? scheme.primary.withValues(alpha: 0.10)
                            : scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _consented
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _consented,
                            onChanged: _submitting
                                ? null
                                : (v) =>
                                      setState(() => _consented = v ?? false),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'I read this to the guest and they consent',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward, size: 19),
              label: const Text('Create & continue to handoff'),
            ),
            const SizedBox(height: 10),
            Text(
              'Approved immediately — you are present to witness it. Next: '
              'capture handoff photos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(DateTime dt) => formatDateTime(dt);
}

/// Tappable date row in the loan-window panel — replaces the ListTiles,
/// which read as navigation rather than editable values.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
          color: onTap == null
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: scheme.onSurfaceVariant),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.edit_outlined, size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Unit stepper, clamped to how many the item actually has.
class _WalkInQuantity extends StatelessWidget {
  const _WalkInQuantity({
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How many units?',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: enabled && value > 1
                    ? () => onChanged(value - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: enabled && value < max
                    ? () => onChanged(value + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This item has $max units in total.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
