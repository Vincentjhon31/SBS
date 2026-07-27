import 'package:flutter/material.dart';

import '../utils/status_colors.dart';

/// Status pill for a borrow_requests row: pending, approved, rejected,
/// released, returned, closed, overdue.
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (status) {
      'pending' => (StatusTone.waiting, 'Pending'),
      'approved' => (StatusTone.positive, 'Approved'),
      'rejected' => (StatusTone.attention, 'Rejected'),
      'released' => (StatusTone.active, 'Released'),
      'returned' => (StatusTone.neutral, 'Returned'),
      'closed' => (StatusTone.neutral, 'Closed'),
      'overdue' => (StatusTone.attention, 'OVERDUE'),
      _ => (StatusTone.neutral, status),
    };
    final (bg, fg) = statusToneColors(tone);
    return Chip(
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
