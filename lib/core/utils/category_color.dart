import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Deterministically maps any staff-typed category string to one of
/// [AppConstants.categoryPalette]'s pastel pairs — same category always
/// gets the same color, new categories still get a legible one
/// automatically, no manual color assignment needed anywhere.
(Color bg, Color fg) categoryColor(String? category) {
  final key = category?.trim().toLowerCase() ?? '';
  if (key.isEmpty) {
    return (const Color(0xFFE6E6EA), const Color(0xFF56565F));
  }
  final hash = key.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  return AppConstants.categoryPalette[hash % AppConstants.categoryPalette.length];
}
