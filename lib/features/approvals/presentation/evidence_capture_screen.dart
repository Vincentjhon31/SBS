import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';

/// Captures evidence at release (photos + liability acknowledgment) or at
/// return (photos + condition notes). Used by the Approver at handoff.
class EvidenceCaptureScreen extends ConsumerStatefulWidget {
  const EvidenceCaptureScreen({super.key, required this.args});

  final EvidenceCaptureArgs args;

  @override
  ConsumerState<EvidenceCaptureScreen> createState() =>
      _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends ConsumerState<EvidenceCaptureScreen> {
  final _notesController = TextEditingController();
  XFile? _borrowerPhoto;
  XFile? _itemPhoto;
  bool _acknowledged = false;
  bool _busy = false;

  bool get isRelease => widget.args.stage == 'release';
  PendingApproval get req => widget.args.request;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pick(bool borrower) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (borrower) {
        _borrowerPhoto = picked;
      } else {
        _itemPhoto = picked;
      }
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_borrowerPhoto == null || _itemPhoto == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Both borrower and item photos are required.')));
      return;
    }
    if (isRelease && !_acknowledged) {
      messenger.showSnackBar(const SnackBar(
          content:
              Text('The borrower must acknowledge the liability terms.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(approvalsRepositoryProvider);
      final Uint8List borrowerBytes = await _borrowerPhoto!.readAsBytes();
      final Uint8List itemBytes = await _itemPhoto!.readAsBytes();
      final notes = _notesController.text.trim();
      if (isRelease) {
        await repo.captureRelease(
          requestId: req.id,
          borrowerPhoto: borrowerBytes,
          itemPhoto: itemBytes,
          termsVersion: AppConstants.liabilityTermsVersion,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await repo.captureReturn(
          requestId: req.id,
          borrowerPhoto: borrowerBytes,
          itemPhoto: itemBytes,
          notes: notes.isEmpty ? null : notes,
        );
      }
      ref.invalidate(approvalQueueProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(isRelease
              ? 'Item released — evidence recorded.'
              : 'Item returned — evidence recorded.')));
      if (mounted) context.go(AppRoutes.approvals);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRelease ? 'Release Item' : 'Confirm Return'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.approvals)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(req.itemLabel,
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Borrower: ${req.borrowerName}'),
              const SizedBox(height: 24),
              _PhotoButton(
                label: 'Borrower photo',
                subtitle: 'The person receiving/returning the item',
                file: _borrowerPhoto,
                onTap: _busy ? null : () => _pick(true),
              ),
              const SizedBox(height: 12),
              _PhotoButton(
                label: 'Item photo',
                subtitle: 'Current condition of the item',
                file: _itemPhoto,
                onTap: _busy ? null : () => _pick(false),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: isRelease
                      ? 'Condition notes at handoff (optional)'
                      : 'Condition notes at return',
                  hintText: isRelease
                      ? 'e.g. existing scratch on left door'
                      : 'e.g. returned complete, no new damage',
                ),
                maxLines: 3,
              ),
              if (isRelease) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Liability terms '
                            '(${AppConstants.liabilityTermsVersion})',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(AppConstants.liabilityTerms,
                            style: Theme.of(context).textTheme.bodySmall),
                        CheckboxListTile(
                          value: _acknowledged,
                          onChanged: _busy
                              ? null
                              : (v) =>
                                  setState(() => _acknowledged = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                              'Borrower acknowledges these terms'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isRelease ? Icons.outbound : Icons.assignment_turned_in),
                label: Text(isRelease ? 'Release item' : 'Confirm return'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.label,
    required this.subtitle,
    required this.file,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final XFile? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = file != null;
    return Card(
      child: ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.add_a_photo_outlined,
          color: done ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(label),
        subtitle: Text(done ? 'Photo captured' : subtitle),
        trailing: done ? const Icon(Icons.edit) : null,
        onTap: onTap,
      ),
    );
  }
}
