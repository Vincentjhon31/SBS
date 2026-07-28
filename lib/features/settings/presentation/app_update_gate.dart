import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_update_providers.dart';
import '../data/app_update_service.dart';

/// Wraps the whole app: checks GitHub Releases once at launch, then shows a
/// one-time dialog and a persistent dismissible banner while an update is
/// pending — mirrors the sibling barangay_events app's updater experience.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final update = await ref.read(
        appUpdateServiceProvider,
      ).checkForUpdate();
      if (!mounted || update == null) return;
      ref.read(pendingUpdateProvider.notifier).set(update);
      unawaited(_showUpdateDialog(update));
    } catch (_) {
      // No network / GitHub unreachable — silently skip. The About page's
      // manual "Check for updates" still lets the user retry.
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Version ${update.latestVersion} is ready. Install it over this '
          'app to keep your data and settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openUpdate(update));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdate(AppUpdateInfo update) async {
    final launched = await launchUrl(
      Uri.parse(update.downloadUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the update link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(pendingUpdateProvider);
    if (update == null) return widget.child;

    return Column(
      children: [
        MaterialBanner(
          content: Text('Version ${update.latestVersion} is available.'),
          actions: [
            TextButton(
              onPressed: () => unawaited(_openUpdate(update)),
              child: const Text('Update'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(pendingUpdateProvider.notifier).set(null),
              child: const Text('Dismiss'),
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
