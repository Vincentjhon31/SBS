import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glossy_background.dart';
import 'admin_data_export.dart';

/// Canned CSV exports for record-keeping — borrow history, item registry,
/// and the citizen list — built client-side from data the app already
/// fetches, no new backend needed.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _busy = false;

  Future<void> _export(Future<String> Function() build, String filename) async {
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Reports')),
      body: GlossyBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  kIsWeb
                      ? 'Downloads a CSV file you can open in a spreadsheet.'
                      : 'Copies CSV to the clipboard — paste into a '
                            'spreadsheet app.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Borrow request history'),
                    subtitle: const Text('Every request, its status, and its dates'),
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    onTap: _busy
                        ? null
                        : () => _export(
                            () => buildBorrowHistoryCsv(ref),
                            'borrow_history.csv',
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Item registry'),
                    subtitle: const Text('Every item, its category, and quantity'),
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    onTap: _busy
                        ? null
                        : () => _export(() => buildItemsCsv(ref), 'items.csv'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Citizen list'),
                    subtitle: const Text('Registered citizens and verification status'),
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    onTap: _busy
                        ? null
                        : () => _export(() => buildCitizensCsv(ref), 'citizens.csv'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
