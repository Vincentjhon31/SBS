import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glossy_background.dart';
import '../data/approvals_models.dart';
import '../data/approvals_providers.dart';

/// Side-by-side release vs. return evidence for a borrow request —
/// the record that settles "what condition was it in, and when".
class EvidenceViewerScreen extends ConsumerWidget {
  const EvidenceViewerScreen({super.key, required this.args});

  final EvidenceViewArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = ref.watch(evidenceProvider(args.requestId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Evidence — ${args.itemLabel}')),
      body: GlossyBackground(
        child: switch (evidence) {
          AsyncData(:final value) when value.isEmpty => const Center(
            child: Text('No evidence captured yet for this request.'),
          ),
          AsyncData(:final value) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StageColumn(
                    title: 'RELEASE',
                    record: _byStage(value, 'release'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StageColumn(
                    title: 'RETURN',
                    record: _byStage(value, 'return'),
                  ),
                ),
              ],
            ),
          ),
          AsyncError() => const Center(child: Text('Could not load evidence.')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  static EvidenceRecord? _byStage(List<EvidenceRecord> records, String stage) {
    for (final record in records) {
      if (record.stage == stage) return record;
    }
    return null;
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.title, required this.record});

  final String title;
  final EvidenceRecord? record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (record == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Not yet captured',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else ...[
          _EvidencePhoto(label: 'Borrower', url: record!.borrowerPhotoUrl),
          const SizedBox(height: 8),
          _EvidencePhoto(label: 'Item', url: record!.itemPhotoUrl),
          const SizedBox(height: 8),
          Text(
            _fmt(record!.capturedAt),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
          if (record!.conditionNotes != null) ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  record!.conditionNotes!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _EvidencePhoto extends StatelessWidget {
  const _EvidencePhoto({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, e, s) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
