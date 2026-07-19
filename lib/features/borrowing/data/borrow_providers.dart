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

final reservedWindowsProvider =
    FutureProvider.family<List<ReservedWindow>, String>(
  (ref, itemId) =>
      ref.watch(borrowRepositoryProvider).fetchReservedWindows(itemId),
);
