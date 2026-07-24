import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const appName = 'SBS';
  static const appFullName = 'Schedule Borrowing System';
  static const appVersion = '0.1.0';

  /// Base seed color for the whole Material color scheme. Bright blue,
  /// shared with the eBongabong Calendar app so the LGU app family reads
  /// as one product.
  static const seedColor = Color(0xFF2B7FFF);

  /// Flat scaffold backgrounds behind the liquid-glass backdrop — a
  /// barely-off-white in light mode, a near-black navy in dark mode.
  static const lightSurface = Color(0xFFF8FCFF);
  static const darkSurface = Color(0xFF05070C);

  /// The three fixed glow-orb hues in the liquid-glass backdrop — a
  /// deliberately varied (blue/green/orange) set rather than shades of
  /// one accent, so the glow reads as soft ambient color, not branding.
  static const glowBlue = Color(0xFF2B7FFF);
  static const glowGreen = Color(0xFF1F9D65);
  static const glowOrange = Color(0xFFFFA726);

  /// The bundled full-color logo (transparent background) shown on the
  /// login, splash, and staff web sidebar.
  static const logoAsset = 'assets/branding/splash_logo.png';

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

  /// Read aloud by staff at walk-in intake — the guest has no app account
  /// to tap their own consent, so staff confirms it on their behalf.
  static const guestConsentStatement =
      'Your name, address, contact number, and the photos taken at '
      'handoff/return will be used solely to verify this borrowing '
      'transaction with the LGU and kept only as long as required for '
      'that record.';
}
