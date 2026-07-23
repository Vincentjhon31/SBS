import 'package:flutter/material.dart';

/// Status pill for an item's live availability: available, reserved_now,
/// out, overdue (see items_status() RPC).
class ItemStatusChip extends StatelessWidget {
  const ItemStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      'available' => (scheme.secondaryContainer, 'Available'),
      'reserved_now' => (scheme.tertiaryContainer, 'Reserved'),
      'out' => (scheme.primaryContainer, 'On loan'),
      'overdue' => (scheme.errorContainer, 'OVERDUE'),
      _ => (scheme.surfaceContainerHighest, status),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
