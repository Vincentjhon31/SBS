import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/data/admin_providers.dart';
import '../../features/approvals/data/approvals_providers.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/borrowing/data/borrow_providers.dart';
import '../../features/items/data/items_providers.dart';

/// Which slice of data a realtime event affects, so one table's churn
/// doesn't refetch every screen in the app.
enum _Slice { requests, evidence, items }

/// Keeps the app's cached queries honest without anyone pressing refresh.
///
/// Every read in this app is a `FutureProvider` over a join-heavy query —
/// the approvals queue alone embeds items, profiles, and guest_borrowers,
/// which Supabase's `.stream()` cannot express. So instead of streaming
/// rows, this listens to `postgres_changes` purely as a doorbell: when
/// borrow_requests / borrow_evidence / items change, it invalidates the
/// providers that read them and they refetch through the normal
/// RLS-guarded path.
///
/// That is what makes the phone and the web dashboard agree: an approver
/// photographing a handoff in the field writes evidence, and the laptop
/// on the desk moves that request out of "To Release" on its own.
///
/// Events are coalesced over [_debounce] because a single release fires
/// several of them (the request row flips status, the evidence row is
/// inserted, the item's availability changes) and they should cost one
/// refetch, not three.
class LiveSync {
  LiveSync(this._ref, this._client) {
    _subscribe();
  }

  final Ref _ref;
  final SupabaseClient _client;

  static const _debounce = Duration(milliseconds: 350);

  RealtimeChannel? _channel;
  Timer? _timer;
  final Set<_Slice> _dirty = {};

  void _subscribe() {
    // Anonymous visitors have no rows to watch, and subscribing before
    // sign-in would open a channel the server rejects under RLS.
    if (_client.auth.currentUser == null) return;

    final channel = _client.channel('sbs-live-sync');
    for (final (table, slice) in const [
      ('borrow_requests', _Slice.requests),
      ('borrow_evidence', _Slice.evidence),
      ('items', _Slice.items),
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _markDirty(slice),
      );
    }
    _channel = channel..subscribe();
  }

  void _markDirty(_Slice slice) {
    _dirty.add(slice);
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  void _flush() {
    final slices = Set<_Slice>.from(_dirty);
    _dirty.clear();
    if (slices.isEmpty) return;

    if (slices.contains(_Slice.requests)) {
      // family provider: invalidating the family clears every status tab.
      _ref.invalidate(approvalQueueProvider);
      _ref.invalidate(myRequestsProvider);
      _ref.invalidate(reservedWindowsProvider);
      _ref.invalidate(superadminStatsProvider);
      _ref.invalidate(superadminTrendsProvider);
    }
    if (slices.contains(_Slice.evidence)) {
      _ref.invalidate(evidenceProvider);
    }
    if (slices.contains(_Slice.items) ||
        slices.contains(_Slice.requests)) {
      // Availability is derived from both the item and the requests
      // currently holding it, so either side moving invalidates it.
      _ref.invalidate(itemsProvider);
      _ref.invalidate(itemStatusesProvider);
    }
  }

  void dispose() {
    _timer?.cancel();
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
  }
}

/// Who the channel belongs to. Deliberately narrowed to the user id
/// rather than watching the raw auth stream: that stream also fires on
/// hourly token refreshes, and rebuilding on those would tear down and
/// re-open the socket every hour for nothing. A Provider only notifies
/// when its value actually changes, so this rebuilds on sign-in and
/// sign-out and stays put in between.
///
/// The `currentUser` fallback covers cold start, where the session is
/// restored from storage before the stream has emitted anything.
final _liveSyncUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final fromStream = ref.watch(authStateChangesProvider).value?.session?.user.id;
  return fromStream ?? client.auth.currentUser?.id;
});

/// Holds one [LiveSync] for the signed-in session — signing in opens the
/// channel, signing out closes it.
///
/// Nothing reads a value off this provider; it exists for its side
/// effect, so it has to be *watched* by a long-lived widget (the app
/// shell) or it would be disposed the moment it was created.
final liveSyncProvider = Provider<LiveSync>((ref) {
  ref.watch(_liveSyncUserIdProvider);
  final sync = LiveSync(ref, ref.watch(supabaseClientProvider));
  ref.onDispose(sync.dispose);
  return sync;
});
