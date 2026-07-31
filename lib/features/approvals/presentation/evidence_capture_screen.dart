import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/glossy_background.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';

const _maxEvidencePhotos = 5;

/// Captures evidence at release (photos + liability acknowledgment) or at
/// return (photos + condition notes). Used by the Approver at handoff.
///
/// One combined set of up to 5 photos — e.g. the borrower photographed
/// holding/using the item — rather than separate borrower/item shots.
class EvidenceCaptureScreen extends ConsumerStatefulWidget {
  const EvidenceCaptureScreen({super.key, required this.args});

  final EvidenceCaptureArgs args;

  @override
  ConsumerState<EvidenceCaptureScreen> createState() =>
      _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends ConsumerState<EvidenceCaptureScreen> {
  final _notesController = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _acknowledged = false;
  bool _busy = false;

  bool get isRelease => widget.args.stage == 'release';
  PendingApproval get req => widget.args.request;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final remaining = _maxEvidencePhotos - _photos.length;
    if (remaining <= 0) return;
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

    if (source == ImageSource.gallery) {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;
      final capped = picked.take(remaining);
      final bytesList = await Future.wait(
        [for (final f in capped) f.readAsBytes()],
      );
      setState(() => _photos.addAll(bytesList));
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photos.add(bytes));
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_photos.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('At least one photo is required.')),
      );
      return;
    }
    if (isRelease && !_acknowledged) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The borrower must acknowledge the liability terms.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(approvalsRepositoryProvider);
      final notes = _notesController.text.trim();
      if (isRelease) {
        await repo.captureRelease(
          requestId: req.id,
          photos: _photos,
          termsVersion: AppConstants.liabilityTermsVersion,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await repo.captureReturn(
          requestId: req.id,
          photos: _photos,
          notes: notes.isEmpty ? null : notes,
        );
      }
      ref.invalidate(approvalQueueProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isRelease
                ? 'Item released — evidence recorded.'
                : 'Item returned — evidence recorded.',
          ),
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isRelease ? 'Release Item' : 'Confirm Return'),
      ),
      body: GlossyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  req.itemLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Borrower: ${req.borrowerName}'),
                const SizedBox(height: 8),
                Text(
                  'Photos (${_photos.length}/$_maxEvidencePhotos) — e.g. the '
                  'borrower holding or using the item',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _PhotoGrid(
                  photos: _photos,
                  onRemove: _busy
                      ? null
                      : (i) => setState(() => _photos.removeAt(i)),
                  onAdd: _busy || _photos.length >= _maxEvidencePhotos
                      ? null
                      : _addPhoto,
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
                          Text(
                            'Liability terms '
                            '(${AppConstants.liabilityTermsVersion})',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.liabilityTerms,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          CheckboxListTile(
                            value: _acknowledged,
                            onChanged: _busy
                                ? null
                                : (v) => setState(
                                    () => _acknowledged = v ?? false,
                                  ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'Borrower acknowledges these terms',
                            ),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isRelease
                              ? Icons.outbound
                              : Icons.assignment_turned_in,
                        ),
                  label: Text(isRelease ? 'Release item' : 'Confirm return'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onRemove,
    required this.onAdd,
  });

  final List<Uint8List> photos;
  final void Function(int index)? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (i, photo) in photos.indexed)
          _PhotoTile(photo: photo, onRemove: onRemove == null ? null : () => onRemove!(i)),
        if (onAdd != null) _AddPhotoTile(onTap: onAdd),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onRemove});

  final Uint8List photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              photo,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black87,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(Icons.add_a_photo_outlined, color: scheme.primary),
      ),
    );
  }
}
