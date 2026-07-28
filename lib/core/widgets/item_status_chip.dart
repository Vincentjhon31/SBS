import 'package:flutter/material.dart';

import '../utils/status_colors.dart';

/// Status pill for an item's live availability: available, reserved_now,
/// out, overdue (see items_status() RPC). For a multi-unit item, pass
/// [quantity]/[availableCount] so "Available" becomes "3 of 5 available"
/// instead of hiding how many units that actually means.
class ItemStatusChip extends StatelessWidget {
  const ItemStatusChip({
    super.key,
    required this.status,
    this.quantity = 1,
    this.availableCount,
  });

  final String status;
  final int quantity;
  final int? availableCount;

  @override
  Widget build(BuildContext context) {
    final showCount = quantity > 1 && availableCount != null;
    final (tone, label) = switch (status) {
      'available' => (
          StatusTone.positive,
          showCount ? '$availableCount of $quantity available' : 'Available',
        ),
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
