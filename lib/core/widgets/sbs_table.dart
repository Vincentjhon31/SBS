import 'package:flutter/material.dart';

/// One row in an [SbsTable]: its cells (aligned to the column order) plus
/// an optional tap handler.
class SbsRow {
  const SbsRow({required this.cells, this.onTap});

  final List<Widget> cells;
  final VoidCallback? onTap;
}

/// A responsive data table. On a wide screen the columns stretch to fill;
/// on a phone the table keeps its natural width and scrolls **horizontally**
/// instead of overflowing — so it's safe on mobile. The whole thing also
/// scrolls vertically, so it can be dropped straight into an `Expanded`.
class SbsTable extends StatelessWidget {
  const SbsTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyText,
  });

  final List<String> columns;
  final List<SbsRow> rows;

  /// Shown centered when [rows] is empty (instead of a bare header).
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && emptyText != null) {
      return Center(child: Text(emptyText!));
    }
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          child: SingleChildScrollView(
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    ),
                    headingTextStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    columns: [
                      for (final c in columns) DataColumn(label: Text(c)),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          onSelectChanged: r.onTap == null
                              ? null
                              : (_) => r.onTap!(),
                          cells: [for (final cell in r.cells) DataCell(cell)],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
