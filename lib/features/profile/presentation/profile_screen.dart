import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';

/// The account tab — profile summary, settings, superadmin dashboard
/// (when applicable), and sign out. Reached via the bottom nav, replacing
/// the old app-bar popup menu.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final isSuperadmin = ref.watch(isSuperadminProvider);

    // The staff website's shell header already shows the page title.
    final inWebShell = kIsWeb && (profile?.isStaff ?? false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: inWebShell
          ? null
          : AppBar(
              title: const Text('Profile'),
              automaticallyImplyLeading: false,
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  profile?.isStaff == true
                      ? Icons.badge_outlined
                      : Icons.person_outline,
                ),
              ),
              title: Text(profile?.fullName ?? '…'),
              subtitle: Text(
                profile == null
                    ? ''
                    : profile.isStaff
                    ? (isSuperadmin ? 'LGU Staff • Superadmin' : 'LGU Staff')
                    : 'Citizen Borrower',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Profile Information'),
                  subtitle: const Text('Name, email, phone, address'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.profileInfo),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Security'),
                  subtitle: const Text('Email and password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.security),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text('Appearance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('Data use and your rights'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Version, updates, FAQs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sign out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
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
    );
  }
}
