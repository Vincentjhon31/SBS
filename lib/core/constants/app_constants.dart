import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const appName = 'SBS';
  static const appFullName = 'Schedule Borrowing System';
  static const appVersion = '1.4.1';

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

  /// Soft pastel palette for the "Blob" background and for category/status
  /// color-coding — deliberately lighter/friendlier than the glow-orb
  /// colors above, so the app reads as colorful without being loud.
  static const pastelSky = Color(0xFFBFE1FF);
  static const pastelMint = Color(0xFFBFF2E0);
  static const pastelPeach = Color(0xFFFFE1B8);
  static const pastelCoral = Color(0xFFFFC9C2);
  static const pastelLavender = Color(0xFFE3D1FF);
  static const pastelPink = Color(0xFFFFE0F3);

  /// (background, foreground) pairs used to color-code item categories and
  /// request/item statuses — cycled through deterministically (by name
  /// hash) rather than assigned by hand, so any new category/staff-typed
  /// value still gets a legible, distinct color automatically.
  static const categoryPalette = <(Color bg, Color fg)>[
    (Color(0xFFBFE1FF), Color(0xFF0B4A8F)), // sky
    (Color(0xFFBFF2E0), Color(0xFF0E6B52)), // mint
    (Color(0xFFFFE1B8), Color(0xFF8A5A00)), // peach
    (Color(0xFFFFC9C2), Color(0xFF9C2B1F)), // coral
    (Color(0xFFE3D1FF), Color(0xFF5B3B96)), // lavender
    (Color(0xFFFFE0F3), Color(0xFF9C1F6E)), // pink
    (Color(0xFFFFF3B0), Color(0xFF7A6A00)), // yellow
    (Color(0xFFBFF4F2), Color(0xFF0B6E6A)), // turquoise
  ];

  /// User-selectable accent seed colors (Settings → Appearance), synced to
  /// `profiles.theme_color` so the choice follows the account, not just the
  /// device. Keys match the DB CHECK constraint values exactly.
  static const accentSeedColors = <String, Color>{
    'blue': Color(0xFF2B7FFF),
    'purple': Color(0xFF6750A4),
    'teal': Color(0xFF149C8B),
    'coral': Color(0xFFE8604C),
    'green': Color(0xFF2E9E5B),
  };

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
