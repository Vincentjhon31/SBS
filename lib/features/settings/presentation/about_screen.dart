import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';
import '../data/app_update_providers.dart';
import '../data/app_update_service.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _faqs = <(String, String)>[
    (
      'How far ahead can I request an item?',
      'As soon as right now — same-day requests are fine — up to a year '
          'in advance.',
    ),
    (
      'When can I pick up my item?',
      'Either on the day you use it, or one day before — you choose the '
          'day and the pickup time when you submit the request.',
    ),
    (
      'Why do I need to verify my identity?',
      'LGU staff verify your ID once, at your first pickup, so the '
          'borrowing record is accountable. After that you\'re verified '
          'for every future request.',
    ),
    (
      'What happens if I return an item late?',
      'It\'s marked overdue and you\'ll get a notification. Staff can see '
          'overdue items in their queue too.',
    ),
    (
      'Can I cancel or change a request?',
      'Not from the app yet — contact the LGU office handling your '
          'request directly.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(installedPackageInfoProvider);
    final release = ref.watch(latestReleaseProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('About')),
      body: GlossyBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const AppLogoBadge(size: 72),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppConstants.appFullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      packageInfo.when(
                        data: (info) => 'Version ${info.version} (${info.buildNumber})',
                        loading: () => 'Version ${AppConstants.appVersion}',
                        error: (_, _) => 'Version ${AppConstants.appVersion}',
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Updates', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    release.when(
                      data: (r) => _UpdateStatus(release: r),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (_, _) => Text(
                        'Could not check for updates right now.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: release.isLoading
                          ? null
                          : () => ref.invalidate(latestReleaseProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Check for updates'),
                    ),
                  ],
                ),
              ),
            ),
            if (release.value?.releaseNotes.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Text(
                "What's new in v${release.value!.version}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(release.value!.releaseNotes),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('FAQs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (question, answer) in _faqs) ...[
                    ExpansionTile(
                      title: Text(question),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(answer)],
                    ),
                    if (question != _faqs.last.$1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Version X is available" + Update now, or "You're up to date" — shown
/// inside the About page's Updates card.
class _UpdateStatus extends StatelessWidget {
  const _UpdateStatus({required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    if (!release.isNewerThanInstalled) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text("You're up to date."),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Version ${release.version} is available.'),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(release.downloadUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Update now'),
        ),
      ],
    );
  }
}
