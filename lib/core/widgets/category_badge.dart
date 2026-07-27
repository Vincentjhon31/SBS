import 'package:flutter/material.dart';

import '../utils/category_color.dart';

/// Small pastel pill for an item's category — same category always gets
/// the same color (see [categoryColor]), so scanning a list of items
/// becomes a color-recognition task instead of a reading task.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final label = category?.trim();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final (bg, fg) = categoryColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
