import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'sbs_view_mode';

/// How list-style screens (Items Registry, Approvals, My Requests) lay
/// out their rows: as a scannable [table] or as [cards]. A device/session
/// preference (like the background style) — not synced to the account.
enum ViewMode { cards, table }

/// Wraps the stored preference. `null` means "auto": follow the screen
/// width (table on wide desktop, cards on a phone). A manual toggle pins
/// an explicit choice that then applies on every width.
class ViewModeController extends Notifier<ViewMode?> {
  static ViewMode? initial;

  @override
  ViewMode? build() => initial;

  Future<void> set(ViewMode? mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, mode.name);
    }
  }
}

final viewModeProvider = NotifierProvider<ViewModeController, ViewMode?>(
  ViewModeController.new,
);

/// Loads the saved preference before the app builds. Call once in main().
Future<ViewMode?> loadSavedViewMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;
  for (final m in ViewMode.values) {
    if (m.name == raw) return m;
  }
  return null;
}

/// Resolves the effective mode for a given available width — honoring an
/// explicit user choice, or falling back to the responsive default.
ViewMode effectiveViewMode(ViewMode? pref, double width) =>
    pref ?? (width >= 720 ? ViewMode.table : ViewMode.cards);

/// A compact segmented toggle (cards / table) for a screen's app bar.
/// Tapping pins an explicit choice; there's no separate "auto" button —
/// the initial state simply follows the width until the user picks.
class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key, required this.width});

  /// The screen's available width, used to show which icon is currently
  /// active when the user hasn't pinned a choice yet.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(viewModeProvider);
    final active = effectiveViewMode(pref, width);
    final controller = ref.read(viewModeProvider.notifier);
    return SegmentedButton<ViewMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(
          value: ViewMode.cards,
          icon: Icon(Icons.grid_view_outlined),
          tooltip: 'Card view',
        ),
        ButtonSegment(
          value: ViewMode.table,
          icon: Icon(Icons.table_rows_outlined),
          tooltip: 'Table view',
        ),
      ],
      selected: {active},
      onSelectionChanged: (s) => controller.set(s.first),
    );
  }
}
