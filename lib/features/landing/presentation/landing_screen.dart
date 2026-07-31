import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../settings/data/app_update_providers.dart';

/// Public marketing/welcome page — the first thing a signed-out web
/// visitor sees at `/`, replacing what used to be a direct redirect to
/// `/login`. Native app users never see this (they're either signed in
/// or land straight on the login screen, since they already "installed"
/// the app from somewhere). Reuses the same GlossyBackground/blob theme
/// as the rest of the app; each section below the hero gets its own
/// pastel tint from the existing palette so the page reads as distinct
/// sections rather than one long scroll.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlossyBackground(
        child: SingleChildScrollView(
          child: Column(
            children: const [
              _HeroSection(),
              _AboutSection(),
              _FeaturesSection(),
              _DownloadSection(),
              _HowToUseSection(),
              _FooterSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width block with its own background tint, giving each section a
/// distinct color per the "different color palette per section" request.
class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 72),
      child: Column(
        children: [
          const AppLogoBadge(size: 108),
          const SizedBox(height: 24),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.appFullName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'Borrow equipment, reserve venues and vehicles, and track every '
            'request — all from one LGU app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text('Sign In'),
                ),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text('Register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppConstants.pastelSky.withValues(alpha: 0.55),
      child: Column(
        children: [
          Text(
            'What is SBS?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            'The Schedule Borrowing System is the Municipality of '
            "Bongabong's way of keeping its shared equipment, vehicles, "
            'and venues organized. Citizens request what they need, LGU '
            'staff review and approve it, and every handoff and return is '
            'tracked with photo evidence — no more paper logs.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = <(IconData, String, String)>[
    (
      Icons.event_outlined,
      'Schedule or Borrow',
      'Reserve a venue or vehicle for a date, or borrow equipment and '
          'tools to take with you — pick the one that fits.',
    ),
    (
      Icons.today_outlined,
      'Same-day requests',
      'No minimum lead time — request something for right now, or plan '
          'up to a year ahead.',
    ),
    (
      Icons.fact_check_outlined,
      'Staff approval',
      'Every request is reviewed by LGU staff before pickup, keeping the '
          'process accountable.',
    ),
    (
      Icons.photo_camera_outlined,
      'Photo evidence',
      "Condition is photographed at handoff and return, so there's a "
          'clear record on both ends.',
    ),
    (
      Icons.notifications_active_outlined,
      'Real-time notifications',
      "You're notified the moment a request is approved, due soon, or "
          'overdue.',
    ),
    (
      Icons.verified_user_outlined,
      'One-time ID verification',
      'Verify your identity once at your first pickup — every request '
          'after that is already accountable.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppConstants.pastelMint.withValues(alpha: 0.55),
      child: Column(
        children: [
          Text(
            'Features',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final (icon, title, body) in _features)
                SizedBox(
                  width: 280,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadSection extends ConsumerWidget {
  const _DownloadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(latestReleaseProvider);
    return _Section(
      color: AppConstants.pastelPeach.withValues(alpha: 0.55),
      child: Column(
        children: [
          const Icon(Icons.android, size: 48, color: Color(0xFF3DDC84)),
          const SizedBox(height: 12),
          Text(
            'Get the app',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Download the Android app for the fastest way to request, '
            'track, and get notified about your borrows.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          release.when(
            data: (r) => FilledButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(r.downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.download),
              label: Text('Download APK (v${r.version})'),
            ),
            loading: () => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const Text('Could not check for a download right now.'),
          ),
        ],
      ),
    );
  }
}

class _HowToUseSection extends StatelessWidget {
  const _HowToUseSection();

  static const _steps = <(String, String)>[
    ('1', 'Register with your full name, a username, contact number, and a valid ID.'),
    ('2', 'Browse items — choose Schedule for venues/vehicles or Borrow for equipment.'),
    ('3', 'Submit a request with your preferred dates and pickup time.'),
    ('4', "Get notified once staff approve it, then pick up on the day you chose."),
    ('5', 'Return the item — photo evidence is captured on both ends of the loan.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppConstants.pastelLavender.withValues(alpha: 0.55),
      child: Column(
        children: [
          Text(
            'How it works',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 32),
          for (final (number, text) in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      number,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      color: AppConstants.pastelPink.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Municipality of Bongabong',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Sign In'),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Text('Register'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} ${AppConstants.appFullName}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
