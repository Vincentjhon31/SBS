import 'package:flutter/material.dart';

/// Status pill for a borrow_requests row: pending, approved, rejected,
/// released, returned, closed, overdue.
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      'pending' => (scheme.tertiaryContainer, 'Pending'),
      'approved' => (scheme.primaryContainer, 'Approved'),
      'rejected' => (scheme.errorContainer, 'Rejected'),
      'released' => (scheme.secondaryContainer, 'Released'),
      'returned' => (scheme.surfaceContainerHighest, 'Returned'),
      'closed' => (scheme.surfaceContainerHighest, 'Closed'),
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
