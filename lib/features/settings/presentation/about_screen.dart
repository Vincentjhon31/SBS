import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _faqs = <(String, String)>[
    (
      'How far ahead can I request an item?',
      'Requests must be made at least a day before you plan to use the '
          'item, and you can book up to a year in advance.',
    ),
    (
      'When can I pick up my item?',
      'Either on the day you use it, or one day before — you choose when '
          'you submit the request.',
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
  Widget build(BuildContext context) {
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
                      'Version ${AppConstants.appVersion}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('What\'s new', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v${AppConstants.appVersion}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Inventory support — items can now have more than one '
                      'unit, so several people can borrow the same kind of '
                      'item at once. Also: live in-app notifications with a '
                      'sound for reminders and overdue alerts, and Blob is '
                      'now the default background.',
                    ),
                  ],
                ),
              ),
            ),
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
