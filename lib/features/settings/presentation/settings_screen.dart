import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/background_style_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';
import '../data/settings_models.dart';
import '../data/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final isStaff = ref.watch(isStaffProvider);
    final isCitizen = profile != null && !profile.isStaff;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings & Data')),
      body: GlossyBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(profile.fullName),
                  subtitle: Text(
                    profile.isStaff ? 'LGU Staff' : 'Citizen Borrower',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ThemeModeSelector(),
                    Divider(height: 32),
                    _AccentColorSelector(),
                    Divider(height: 32),
                    _BackgroundStyleSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Data Privacy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppConstants.dataPolicyStatement),
                    const SizedBox(height: 8),
                    Text(
                      'Photos are retained for up to 12 months and then '
                      'automatically removed; your transaction records are '
                      'kept as the LGU\'s accountability history.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isCitizen) ...[
                      const Divider(height: 24),
                      const _ConsentStatus(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Your Data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Export my data'),
                    subtitle: const Text(
                      'Download a copy of everything SBS holds about you',
                    ),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final data = await ref
                            .read(settingsRepositoryProvider)
                            .exportMyData();
                        if (context.mounted) {
                          context.push(AppRoutes.dataExport, extra: data);
                        }
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not export data.'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  const _DeletionRequestTile(),
                ],
              ),
            ),
            if (isStaff) ...[
              const SizedBox(height: 16),
              Text(
                'Deletion Requests to Handle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const _StaffDeletionQueue(),
            ],
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

class _AccentColorSelector extends ConsumerWidget {
  const _AccentColorSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(myProfileProvider).value?.themeColor ?? 'blue';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accent color', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Synced to your account — follows you across devices',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'blue',
              icon: Icon(Icons.circle, color: AppConstants.seedColor),
              label: const Text('Blue'),
            ),
            ButtonSegment(
              value: 'purple',
              icon: Icon(Icons.circle, color: AppConstants.purpleSeedColor),
              label: const Text('Purple'),
            ),
          ],
          selected: {themeColor},
          onSelectionChanged: (selection) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(settingsRepositoryProvider)
                  .updateThemeColor(selection.first);
              ref.invalidate(myProfileProvider);
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Could not update accent color.')),
              );
            }
          },
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
          'Glossy adds soft color glow behind screens; Solid is flat and '
          'lighter on slower devices.',
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

class _ConsentStatus extends ConsumerWidget {
  const _ConsentStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(myConsentInfoProvider);
    return switch (consent) {
      AsyncData(value: final ConsentInfo info) => Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You consented on ${_date(info.consentedAt)}'
              '${info.verified ? " • identity verified" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _DeletionRequestTile extends ConsumerWidget {
  const _DeletionRequestTile();

  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account data deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'LGU staff will review your request and remove your personal '
              'details (name, contact, ID). Your borrowing history stays '
              'on record as required for accountability.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .requestDeletion(controller.text);
      ref.invalidate(myDeletionRequestProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Deletion request submitted.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not submit request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(myDeletionRequestProvider);
    return switch (request) {
      AsyncData(value: final DeletionRequest? r) when r == null => ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Request account data deletion'),
        onTap: () => _requestDeletion(context, ref),
      ),
      AsyncData(value: final DeletionRequest? r) when r?.status == 'pending' =>
        ListTile(
          leading: Icon(
            Icons.hourglass_top,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          title: const Text('Deletion request pending'),
          subtitle: Text('Submitted ${_date(r!.requestedAt)}'),
        ),
      AsyncData(value: final DeletionRequest? r) => ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: const Text('Deletion request completed'),
        subtitle: Text('Completed ${_date(r!.completedAt!)}'),
        onTap: () => _requestDeletion(context, ref),
      ),
      _ => const ListTile(title: Text('Loading…')),
    };
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _StaffDeletionQueue extends ConsumerWidget {
  const _StaffDeletionQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingDeletionRequestsProvider);
    return switch (queue) {
      AsyncData(value: final List<DeletionRequest> items) when items.isEmpty =>
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No pending deletion requests.'),
          ),
        ),
      AsyncData(value: final List<DeletionRequest> items) => Card(
        child: Column(
          children: [
            for (final r in items)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: Text(r.requesterName ?? 'Unknown user'),
                subtitle: Text(
                  [
                    'Requested ${_date(r.requestedAt)}',
                    if (r.reason != null) r.reason!,
                  ].join(' • '),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm deletion'),
                        content: Text(
                          'This permanently anonymizes ${r.requesterName}\'s '
                          'name, contact, ID number, and ID photo. Their '
                          'borrowing history is kept. This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Anonymize & complete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(settingsRepositoryProvider)
                          .completeDeletionRequest(r.id);
                      ref.invalidate(pendingDeletionRequestsProvider);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Request completed.')),
                      );
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Could not complete request.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Process'),
                ),
              ),
          ],
        ),
      ),
      AsyncError() => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not load deletion requests.'),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
