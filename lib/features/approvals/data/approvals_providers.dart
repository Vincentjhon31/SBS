import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'approvals_models.dart';
import 'approvals_repository.dart';

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => ApprovalsRepository(ref.watch(supabaseClientProvider)),
);

final approvalQueueProvider = FutureProvider.family<ApprovalQueue, String>(
  (ref, status) => ref.watch(approvalsRepositoryProvider).fetchQueue(status),
);

final pendingApprovalsProvider = FutureProvider<List<PendingApproval>>(
  (ref) async => (await ref.watch(approvalQueueProvider('pending').future))
      .requests,
);

final evidenceProvider = FutureProvider.family<List<EvidenceRecord>, String>(
  (ref, requestId) =>
      ref.watch(approvalsRepositoryProvider).fetchEvidence(requestId),
);

final citizenVerificationProvider =
    FutureProvider.family<CitizenVerification, String>(
  (ref, borrowerId) =>
      ref.watch(approvalsRepositoryProvider).fetchCitizenVerification(borrowerId),
);
