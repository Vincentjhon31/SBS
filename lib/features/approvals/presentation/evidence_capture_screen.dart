import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/workbench_scaffold.dart';
import '../../admin/data/admin_providers.dart';
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
        final settings = ref.read(appSettingsProvider).value;
        await repo.captureRelease(
          requestId: req.id,
          photos: _photos,
          termsVersion:
              settings?['liability_terms_version'] ??
              AppConstants.liabilityTermsVersion,
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
    final settings = ref.watch(appSettingsProvider).value;
    final termsVersion =
        settings?['liability_terms_version'] ??
        AppConstants.liabilityTermsVersion;
    final termsText = settings?['liability_terms'] ?? AppConstants.liabilityTerms;
    final scheme = Theme.of(context).colorScheme;
    final accent = isRelease
        ? const Color(0xFF2B7FFF)
        : const Color(0xFF1F9D65);
    final canSubmit =
        _photos.isNotEmpty && (!isRelease || _acknowledged) && !_busy;

    return WorkbenchScaffold(
      title: isRelease ? 'Release Item' : 'Confirm Return',
      subtitle: req.itemLabel,
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkbenchCard(
            title: 'Photo evidence',
            icon: Icons.photo_camera_outlined,
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRelease
                      ? 'Photograph the item at handoff — ideally with the '
                            'borrower holding it — so its condition is on '
                            'record before it leaves.'
                      : 'Photograph the item as returned, so any new damage '
                            'is on record against the handoff photos.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _PhotoGrid(
                  photos: _photos,
                  onRemove: _busy
                      ? null
                      : (i) => setState(() => _photos.removeAt(i)),
                  onAdd: _busy || _photos.length >= _maxEvidencePhotos
                      ? null
                      : _addPhoto,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _photos.isEmpty
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 15,
                      color: _photos.isEmpty ? scheme.error : accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _photos.isEmpty
                          ? 'At least one photo is required'
                          : '${_photos.length} of $_maxEvidencePhotos photos added',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _photos.isEmpty
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkbenchCard(
            title: 'Condition notes',
            icon: Icons.notes_outlined,
            accent: accent,
            child: TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: isRelease
                    ? 'Notes at handoff (optional)'
                    : 'Notes at return',
                hintText: isRelease
                    ? 'e.g. existing scratch on left door'
                    : 'e.g. returned complete, no new damage',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
          ),
        ],
      ),
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkbenchCard(
            title: 'Handoff',
            icon: Icons.swap_horiz,
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkbenchField(
                  icon: Icons.inventory_2_outlined,
                  label: 'ITEM',
                  value: req.itemLabel,
                ),
                WorkbenchField(
                  icon: Icons.person_outline,
                  label: 'BORROWER',
                  value: req.borrowerName,
                ),
                if (req.itemQuantity > 1)
                  WorkbenchField(
                    icon: Icons.pin_outlined,
                    label: 'QUANTITY',
                    value:
                        '${req.quantityRequested} of ${req.itemQuantity} units',
                  ),
              ],
            ),
          ),
          if (isRelease) ...[
            const SizedBox(height: 16),
            WorkbenchCard(
              title: 'Liability terms',
              icon: Icons.gavel_outlined,
              accent: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Version $termsVersion',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Scroll-capped rather than free-flowing: the terms are
                  // long enough to push the confirm button off a laptop
                  // screen entirely.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(
                        termsText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _busy
                        ? null
                        : () => setState(() => _acknowledged = !_acknowledged),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _acknowledged
                            ? accent.withValues(alpha: 0.12)
                            : scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _acknowledged
                              ? accent.withValues(alpha: 0.5)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _acknowledged,
                            onChanged: _busy
                                ? null
                                : (v) => setState(
                                    () => _acknowledged = v ?? false,
                                  ),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Borrower acknowledges these terms',
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
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isRelease ? Icons.outbound : Icons.assignment_turned_in,
                    size: 19,
                  ),
            label: Text(isRelease ? 'Release item' : 'Confirm return'),
          ),
          if (!canSubmit && !_busy) ...[
            const SizedBox(height: 10),
            Text(
              _photos.isEmpty
                  ? 'Add at least one photo to continue.'
                  : 'Tick the liability acknowledgement to continue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
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
