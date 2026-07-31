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

final superadminTrendsProvider = FutureProvider<DashboardTrends>(
  (ref) => ref.watch(adminRepositoryProvider).fetchTrends(),
);

final allStaffProvider = FutureProvider<List<StaffMember>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAllStaff(),
);

final allMembershipsProvider = FutureProvider<List<DepartmentMembership>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAllMemberships(),
);

final allUsersProvider = FutureProvider<List<UserAccount>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAllUsers(),
);

final auditLogProvider = FutureProvider<List<AuditLogEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAuditLog(),
);

/// Superadmin-editable policy text (falls back to AppConstants below when
/// no row exists yet, e.g. before the first `supabase db push`).
final appSettingsProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAppSettings(),
);
