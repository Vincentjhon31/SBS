import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_service.dart';

final installedPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => GitHubReleaseUpdateService(
    repositoryOwner: 'Vincentjhon31',
    repositoryName: 'SBS',
  ),
);

/// Fetched once per app session (About page's "What's New" re-triggers this
/// via `ref.invalidate` on its manual "Check for updates" button).
final latestReleaseProvider = FutureProvider<AppReleaseInfo>(
  (ref) => ref.watch(appUpdateServiceProvider).fetchLatestRelease(),
);

/// Set once at launch and read by the banner/dialog/nav dot. Cleared when
/// the user dismisses the banner, until the next launch.
class PendingUpdateController extends Notifier<AppUpdateInfo?> {
  @override
  AppUpdateInfo? build() => null;

  void set(AppUpdateInfo? info) => state = info;
}

final pendingUpdateProvider =
    NotifierProvider<PendingUpdateController, AppUpdateInfo?>(
      PendingUpdateController.new,
    );
