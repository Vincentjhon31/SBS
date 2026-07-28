import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(supabaseClientProvider)),
);

final myConsentInfoProvider = FutureProvider(
  (ref) => ref.watch(settingsRepositoryProvider).myConsentInfo(),
);

final myDeletionRequestProvider = FutureProvider(
  (ref) => ref.watch(settingsRepositoryProvider).myDeletionRequest(),
);

final pendingDeletionRequestsProvider = FutureProvider(
  (ref) => ref.watch(settingsRepositoryProvider).pendingDeletionRequests(),
);

final myProfileInfoProvider = FutureProvider(
  (ref) => ref.watch(settingsRepositoryProvider).myProfileInfo(),
);
