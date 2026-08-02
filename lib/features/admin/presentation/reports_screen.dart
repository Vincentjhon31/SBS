import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_animations.dart';
import 'admin_data_export.dart';
import 'admin_page.dart';

const _accent = Color(0xFF00696E);

/// Canned CSV exports for record-keeping, built client-side from data the
/// app already fetches.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  /// Which report is currently building — lets the tapped row show a
  /// spinner while the others stay usable-looking rather than all three
  /// going busy at once.
  String? _busy;

  Future<void> _export(
    String key,
    Future<String> Function() build,
    String filename,
  ) async {
    setState(() => _busy = key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await build();
      if (!mounted) return;
      await downloadCsv(context, filename, csv);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not build that export.')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reports = <(String, IconData, String, String, Future<String> Function(), String)>[
      (
        'history',
        Icons.receipt_long_outlined,
        'Borrow request history',
        'Every request with its status, quantity, and dates.',
        () => buildBorrowHistoryCsv(ref),
        'borrow_history.csv',
      ),
      (
        'items',
        Icons.inventory_2_outlined,
        'Item registry',
        'Every item with its category, department, and quantity.',
        () => buildItemsCsv(ref),
        'items.csv',
      ),
      (
        'citizens',
        Icons.people_outline,
        'Citizen list',
        'Registered citizens and their ID verification status.',
        () => buildCitizensCsv(ref),
        'citizens.csv',
      ),
    ];

    return AdminPage(
      icon: Icons.summarize_outlined,
      title: 'Reports',
      subtitle: kIsWeb
          ? 'Download a CSV you can open in Excel or Google Sheets.'
          : 'Copies CSV to the clipboard to paste into a spreadsheet.',
      accent: _accent,
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          for (var i = 0; i < reports.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                icon: reports[i].$2,
                title: reports[i].$3,
                description: reports[i].$4,
                busy: _busy == reports[i].$1,
                // One export at a time: they all read from the same
                // repositories, and a half-finished second file helps
                // nobody.
                enabled: _busy == null,
                onTap: () =>
                    _export(reports[i].$1, reports[i].$5, reports[i].$6),
              ),
            ).fadeUpAt(i),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exports contain personal data. Store and share them '
                  'according to the LGU records policy.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ).fadeUpAt(reports.length),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: AdminCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: _accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.download_outlined, color: _accent),
          ],
        ),
      ),
    );
  }
}
