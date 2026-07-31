import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_providers.dart';

/// Wraps the whole app: if the signed-in user's account gets deactivated
/// (Users management) while they hold a live session, force a sign-out
/// and explain why, instead of leaving them in a half-signed-in state
/// until their next natural sign-out.
class AccountActiveGate extends ConsumerStatefulWidget {
  const AccountActiveGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountActiveGate> createState() => _AccountActiveGateState();
}

class _AccountActiveGateState extends ConsumerState<AccountActiveGate> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Profile?>>(myProfileProvider, (previous, next) {
      final profile = next.value;
      if (profile == null) {
        _handled = false;
        return;
      }
      if (!profile.active && !_handled) {
        _handled = true;
        _forceSignOut();
      }
    });
    return widget.child;
  }

  Future<void> _forceSignOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account deactivated'),
        content: const Text(
          'Your account has been deactivated. Contact the LGU office for '
          'assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
