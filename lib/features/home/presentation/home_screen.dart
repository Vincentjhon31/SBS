import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_providers.dart';

/// Placeholder shell — replaced by the real dashboard in later phases.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final verified = ref.watch(myCitizenVerifiedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              switch (profile) {
                AsyncData(:final value) when value != null => Column(
                    children: [
                      Text(
                        'Welcome, ${value.fullName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          value.isStaff ? 'LGU Staff' : 'Citizen Borrower',
                        ),
                      ),
                    ],
                  ),
                AsyncError() => const Text('Could not load your profile.'),
                _ => const CircularProgressIndicator(),
              },
              if (verified case AsyncData(value: false)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_top,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Identity verification pending — an LGU approver '
                            'will verify your ID on your first request.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Items Registry'),
                  subtitle:
                      const Text('Browse borrowable items, venues, vehicles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.items),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'v${AppConstants.appVersion} — borrowing features arrive in '
                'the next phases',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
