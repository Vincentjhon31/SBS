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

/// Active + inactive — for the department management screen only; every
/// other consumer (item-assignment dropdowns) wants [departmentsProvider].
final allDepartmentsProvider = FutureProvider<List<Department>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchAllDepartments(),
);

final myDepartmentIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(itemsRepositoryProvider).fetchMyDepartmentIds(),
);

/// Live search text for the Items Registry. Shared state (rather than
/// screen-local) so the staff web header's global search box can set it
/// and jump to the Items tab with the query already applied.
class ItemsQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final itemsQueryProvider = NotifierProvider<ItemsQuery, String>(ItemsQuery.new);

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
