import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/background_style_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../auth/data/auth_providers.dart';
import '../data/settings_providers.dart';

/// Appearance only — profile/account fields live on Profile Information,
/// credentials on Security, and data rights on Privacy Policy, so this
/// screen stays focused on "how the app looks."
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: GlossyBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ThemeModeSelector(),
                    if (profile != null) ...[
                      const Divider(height: 32),
                      const _AccentColorSelector(),
                    ],
                    const Divider(height: 32),
                    const _BackgroundStyleSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'SBS v${AppConstants.appVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(selection.first),
        ),
      ],
    );
  }
}

class _BackgroundStyleSelector extends ConsumerWidget {
  const _BackgroundStyleSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(backgroundStyleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Background', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Glossy adds a soft color glow behind screens; Blob shows flat '
          'pastel floating shapes; Solid is flat and lighter on slower '
          'devices.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<BackgroundStyle>(
          segments: const [
            ButtonSegment(
              value: BackgroundStyle.glossy,
              icon: Icon(Icons.blur_on_outlined),
              label: Text('Glossy'),
            ),
            ButtonSegment(
              value: BackgroundStyle.blob,
              icon: Icon(Icons.bubble_chart_outlined),
              label: Text('Blob'),
            ),
            ButtonSegment(
              value: BackgroundStyle.solid,
              icon: Icon(Icons.crop_square_outlined),
              label: Text('Solid'),
            ),
          ],
          selected: {style},
          onSelectionChanged: (selection) => ref
              .read(backgroundStyleProvider.notifier)
              .setStyle(selection.first),
        ),
      ],
    );
  }
}

class _AccentColorSelector extends ConsumerWidget {
  const _AccentColorSelector();

  static const _labels = {
    'blue': 'Blue',
    'purple': 'Purple',
    'teal': 'Teal',
    'coral': 'Coral',
    'green': 'Green',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final selected = profile?.themeColor ?? 'blue';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accent Color', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Colors the buttons, highlights, and icons across the whole app. '
          'Saved to your account.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in AppConstants.accentSeedColors.entries)
              _AccentSwatch(
                color: entry.value,
                label: _labels[entry.key] ?? entry.key,
                isSelected: entry.key == selected,
                onTap: () => ref
                    .read(settingsRepositoryProvider)
                    .updateThemeColor(entry.key)
                    .then((_) => ref.invalidate(myProfileProvider)),
              ),
          ],
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
