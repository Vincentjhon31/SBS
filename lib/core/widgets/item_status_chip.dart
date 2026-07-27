import 'package:flutter/material.dart';

import '../utils/status_colors.dart';

/// Status pill for an item's live availability: available, reserved_now,
/// out, overdue (see items_status() RPC).
class ItemStatusChip extends StatelessWidget {
  const ItemStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (status) {
      'available' => (StatusTone.positive, 'Available'),
      'reserved_now' => (StatusTone.waiting, 'Reserved'),
      'out' => (StatusTone.active, 'On loan'),
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
