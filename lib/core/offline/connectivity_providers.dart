import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network interface up.
///
/// This is a *transport* signal, not a reachability one: a phone on
/// barangay wifi with a dead uplink still reports online. That's fine for
/// what it drives — the offline banner and the "flush the queue now"
/// trigger — because every write still goes through the queue, which
/// retries on failure regardless of what this says. Treating an unknown
/// state as online keeps the app from falsely blocking work.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_online);
});

bool _online(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Convenience read of [connectivityProvider] that assumes online until
/// proven otherwise, so a slow first check never shows a false alarm.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);
