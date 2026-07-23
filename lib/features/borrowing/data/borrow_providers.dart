import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'borrow_models.dart';
import 'borrow_repository.dart';

final borrowRepositoryProvider = Provider<BorrowRepository>(
  (ref) => BorrowRepository(ref.watch(supabaseClientProvider)),
);

final myRequestsProvider = FutureProvider<List<BorrowRequest>>(
  (ref) => ref.watch(borrowRepositoryProvider).fetchMyRequests(),
);

const _activeStatuses = {'pending', 'approved', 'released', 'overdue'};

/// The caller's not-yet-closed requests, soonest obligation first (due
/// date when set, otherwise start date). Shared by My Requests' Active tab
/// and Home's "My Borrowed Items" preview.
final activeRequestsProvider = Provider<List<BorrowRequest>>((ref) {
  final requests = ref.watch(myRequestsProvider).value ?? const [];
  final active = [
    for (final r in requests)
      if (_activeStatuses.contains(r.status)) r,
  ];
  active.sort((a, b) =>
      (a.dueAt ?? a.requestedFrom).compareTo(b.dueAt ?? b.requestedFrom));
  return active;
});

/// The caller's closed-out requests (rejected/returned/closed) — the
/// complement of [activeRequestsProvider], for My Requests' History tab.
final historyRequestsProvider = Provider<List<BorrowRequest>>((ref) {
  final requests = ref.watch(myRequestsProvider).value ?? const [];
  return [
    for (final r in requests)
      if (!_activeStatuses.contains(r.status)) r,
  ];
});

final reservedWindowsProvider =
    FutureProvider.family<List<ReservedWindow>, String>(
  (ref, itemId) =>
      ref.watch(borrowRepositoryProvider).fetchReservedWindows(itemId),
);
