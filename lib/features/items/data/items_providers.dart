import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'items_models.dart';
import 'items_repository.dart';

final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(supabaseClientProvider)),
);

final itemsProvider = FutureProvider<List<Item>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchItems(),
);

final departmentsProvider = FutureProvider<List<Department>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchDepartments(),
);

final myDepartmentIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchMyDepartmentIds(),
);

final isStaffProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider);
  return profile.value?.isStaff ?? false;
});

final isSuperadminProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider);
  return profile.value?.isSuperadmin ?? false;
});

final itemPhotoUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(itemsRepositoryProvider).signedPhotoUrl(path),
);

final itemStatusesProvider = FutureProvider<Map<String, ItemStatus>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchStatuses(),
);
