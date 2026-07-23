import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const appName = 'SBS';
  static const appFullName = 'Schedule Borrowing System';
  static const appVersion = '0.1.0';

  /// Civic blue — default accent color, placeholder until official LGU
  /// branding is provided.
  static const seedColor = Color(0xFF1A4B8C);

  /// Alternate accent color users may switch to in Settings.
  static const purpleSeedColor = Color(0xFF6750A4);

  static const splashDuration = Duration(milliseconds: 1500);

  /// Versioned so policy changes never retroactively alter what past
  /// borrowers agreed to.
  static const liabilityTermsVersion = 'v1';
  static const liabilityTerms =
      'I acknowledge receiving this item in the condition shown in the '
      'photos taken at handoff. I agree to return it in the same condition '
      'on or before the stated due date, and I accept responsibility for '
      'loss or damage while it is in my care.';

  static const dataPolicyStatement =
      'Your photo and ID information are used solely to verify borrowing '
      'transactions with the LGU. You can request an export or deletion of '
      'your personal data at any time from Settings.';
}
