import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_animations.dart';
import '../../auth/data/auth_providers.dart';
import '../../items/data/items_providers.dart';

/// The account tab — identity summary, settings, and sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final isSuperadmin = ref.watch(isSuperadminProvider);
    final verified = ref.watch(myCitizenVerifiedProvider).value;
    final isStaff = profile?.isStaff ?? false;

    // The staff website's shell header already shows the page title.
    final inWebShell = kIsWeb && isStaff;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: inWebShell
          ? null
          : AppBar(
              title: const Text('Profile'),
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _IdentityCard(
                fullName: profile?.fullName,
                username: profile?.username,
                isStaff: isStaff,
                isSuperadmin: isSuperadmin,
                verified: verified,
              ).fadeUp(),
              const SizedBox(height: 22),
              _GroupLabel('Account').fadeUp(
                delay: const Duration(milliseconds: 60),
              ),
              const SizedBox(height: 8),
              _SettingsGroup(
                tiles: [
                  (
                    Icons.badge_outlined,
                    'Profile information',
                    // Citizens have no email on file since the username
                    // change — listing one here would be misleading.
                    isStaff
                        ? 'Name and contact details'
                        : 'Name, contact number, ID, and address',
                    AppRoutes.profileInfo,
                  ),
                  (
                    Icons.lock_outline,
                    'Security',
                    isStaff ? 'Email and password' : 'Password',
                    AppRoutes.security,
                  ),
                ],
              ).fadeUp(delay: const Duration(milliseconds: 100)),
              const SizedBox(height: 22),
              _GroupLabel('App').fadeUp(
                delay: const Duration(milliseconds: 140),
              ),
              const SizedBox(height: 8),
              _SettingsGroup(
                tiles: const [
                  (
                    Icons.palette_outlined,
                    'Appearance',
                    'Theme, accent colour, and background',
                    AppRoutes.settings,
                  ),
                  (
                    Icons.privacy_tip_outlined,
                    'Privacy policy',
                    'How your data is used, and your rights',
                    AppRoutes.privacyPolicy,
                  ),
                  (
                    Icons.info_outline,
                    'About',
                    'Version, updates, and FAQs',
                    AppRoutes.about,
                  ),
                ],
              ).fadeUp(delay: const Duration(milliseconds: 180)),
              const SizedBox(height: 22),
              _SignOutTile().fadeUp(
                delay: const Duration(milliseconds: 220),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '${AppConstants.appName} v${AppConstants.appVersion}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ).fadeUp(delay: const Duration(milliseconds: 260)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient header carrying the avatar, name, handle, and role/verification
/// state — the things someone opens this tab to confirm.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.fullName,
    required this.username,
    required this.isStaff,
    required this.isSuperadmin,
    required this.verified,
  });

  final String? fullName;
  final String? username;
  final bool isStaff;
  final bool isSuperadmin;
  final bool? verified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = fullName ?? '…';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.75),
            scheme.surfaceContainerHigh.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (username != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      icon: isStaff
                          ? Icons.badge_outlined
                          : Icons.person_outline,
                      label: isStaff ? 'LGU Staff' : 'Citizen Borrower',
                      color: isStaff ? scheme.tertiary : scheme.primary,
                    ),
                    if (isSuperadmin)
                      _Pill(
                        icon: Icons.shield_outlined,
                        label: 'Superadmin',
                        color: scheme.tertiary,
                      ),
                    if (!isStaff && verified != null)
                      _Pill(
                        icon: verified!
                            ? Icons.verified_user_outlined
                            : Icons.hourglass_empty,
                        label: verified! ? 'ID verified' : 'Verification pending',
                        color: verified!
                            ? const Color(0xFF1F9D65)
                            : const Color(0xFFE07A1F),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.tiles});

  final List<(IconData, String, String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58),
            ListTile(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tiles[i].$1, size: 17, color: scheme.primary),
              ),
              title: Text(
                tiles[i].$2,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(tiles[i].$3),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => context.push(tiles[i].$4),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignOutTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.logout, size: 17, color: scheme.error),
        ),
        title: Text(
          'Sign out',
          style: TextStyle(
            color: scheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _confirm(context, ref),
      ),
    );
  }

  /// Confirmed rather than immediate: a mis-tap here used to drop the
  /// session, and citizens sign back in with a username they may not use
  /// often enough to have memorised.
  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
        title: const Text('Sign out?'),
        content: const Text('You will need your credentials to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}
