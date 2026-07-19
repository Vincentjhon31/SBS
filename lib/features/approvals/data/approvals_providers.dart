import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'approvals_models.dart';
import 'approvals_repository.dart';

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => ApprovalsRepository(ref.watch(supabaseClientProvider)),
);

final pendingApprovalsProvider = FutureProvider<List<PendingApproval>>(
  (ref) => ref.watch(approvalsRepositoryProvider).fetchPending(),
);

final citizenVerificationProvider =
    FutureProvider.family<CitizenVerification, String>(
  (ref, borrowerId) =>
      ref.watch(approvalsRepositoryProvider).fetchCitizenVerification(borrowerId),
);
