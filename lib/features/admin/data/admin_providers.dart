import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

final superadminStatsProvider = FutureProvider<SuperadminStats>(
  (ref) => ref.watch(adminRepositoryProvider).fetchStats(),
);

final allStaffProvider = FutureProvider<List<StaffMember>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAllStaff(),
);

final allMembershipsProvider = FutureProvider<List<DepartmentMembership>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAllMemberships(),
);
