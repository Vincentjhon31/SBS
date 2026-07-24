import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/glossy_background.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Walk-in Request')),
      body: GlossyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Borrower details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Full name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
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
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Borrow details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text('Borrow from: ${_format(_from)}'),
                    onTap: _submitting
                        ? null
                        : () => _pickDateTime(isFrom: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available),
                    title: Text(
                      _to == null
                          ? 'Return by…'
                          : 'Return by: ${_format(_to!)}',
                    ),
                    enabled: !_notSureWhenReturning,
                    onTap: _submitting || _notSureWhenReturning
                        ? null
                        : () => _pickDateTime(isFrom: false),
                  ),
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
                    title: const Text('Not sure when returning'),
                    subtitle: const Text(
                      'This item stays reserved to them until it\'s marked returned',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data privacy notice',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.guestConsentStatement,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          CheckboxListTile(
                            value: _consented,
                            onChanged: _submitting
                                ? null
                                : (v) =>
                                      setState(() => _consented = v ?? false),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'I read this notice to the guest and they consent',
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        : const Text('Create & continue to handoff'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This request is approved immediately — you\'re present to '
                    'witness it. Next: capture handoff photos.',
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

  static String _format(DateTime dt) {
    final d =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
