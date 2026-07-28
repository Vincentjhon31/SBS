import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/full_image_viewer.dart';
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
          AsyncData(:final value) => SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final release = _StageCard(
                        title: 'Release',
                        icon: Icons.logout,
                        record: _byStage(value, 'release'),
                      );
                      final ret = _StageCard(
                        title: 'Return',
                        icon: Icons.login,
                        record: _byStage(value, 'return'),
                      );
                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            release,
                            const SizedBox(height: 12),
                            ret,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: release),
                          const SizedBox(width: 12),
                          Expanded(child: ret),
                        ],
                      );
                    },
                  ),
                ),
              ),
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

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.icon,
    required this.record,
  });

  final String title;
  final IconData icon;
  final EvidenceRecord? record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record == null)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Not yet captured',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _EvidencePhoto(
                      label: 'Borrower',
                      url: record!.borrowerPhotoUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EvidencePhoto(
                      label: 'Item',
                      url: record!.itemPhotoUrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _fmt(record!.capturedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (record!.conditionNotes != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    record!.conditionNotes!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) => formatDateTime(dt);
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
        GestureDetector(
          onTap: () => showFullImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (context, e, s) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
