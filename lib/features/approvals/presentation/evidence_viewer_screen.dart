import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_animations.dart';
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

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Evidence'),
            Text(
              args.itemLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: GlossyBackground(
        child: switch (evidence) {
          AsyncData(:final value) when value.isEmpty => const _NoEvidence(),
          AsyncData(:final value) => SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final release = _StageCard(
                        title: 'Released',
                        icon: Icons.outbound,
                        accent: const Color(0xFF2B7FFF),
                        record: _byStage(value, 'release'),
                      );
                      final ret = _StageCard(
                        title: 'Returned',
                        icon: Icons.assignment_turned_in,
                        accent: const Color(0xFF1F9D65),
                        record: _byStage(value, 'return'),
                      );
                      // Side by side is the point of this screen —
                      // handoff condition against return condition. Only
                      // stack once there is genuinely no room.
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            release.fadeUp(),
                            const SizedBox(height: 14),
                            ret.fadeUp(
                              delay: const Duration(milliseconds: 90),
                            ),
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: release.fadeUp()),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ret.fadeUp(
                                delay: const Duration(milliseconds: 90),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          AsyncError() => const _NoEvidence(
            icon: Icons.error_outline,
            title: 'Could not load evidence',
            hint: 'Check your connection and try again.',
          ),
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

/// Empty / error panel for the evidence screen.
class _NoEvidence extends StatelessWidget {
  const _NoEvidence({
    this.icon = Icons.photo_library_outlined,
    this.title = 'No evidence captured yet',
    this.hint =
        'Photos taken at handoff and at return will appear here once this '
            'request reaches those steps.',
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 33, color: scheme.onSurfaceVariant),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ).fadeUp(delay: const Duration(milliseconds: 80)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ).fadeUp(delay: const Duration(milliseconds: 130)),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.icon,
    required this.record,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final EvidenceRecord? record;

  /// Hue for this stage — blue for release, green for return — so the two
  /// halves of the comparison are distinguishable at a glance.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: record == null
              ? scheme.outlineVariant.withValues(alpha: 0.7)
              : accent.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (record != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${record!.photoUrls.length} '
                      '${record!.photoUrls.length == 1 ? "photo" : "photos"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final url in record!.photoUrls)
                    _EvidencePhoto(url: url),
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
  const _EvidencePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showFullImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 100,
          height: 100,
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
    );
  }
}
