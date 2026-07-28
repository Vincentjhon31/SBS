import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Checks GitHub Releases for a newer version — SBS isn't distributed
/// through the Play Store, so this is the only "is there an update"
/// signal available. Ported from the sibling barangay_events project.
abstract class AppUpdateService {
  /// Null when the installed version is already current — used for the
  /// launch-time popup, which should stay silent unless there's actually
  /// something newer.
  Future<AppUpdateInfo?> checkForUpdate();

  /// Always returns the latest release's info regardless of update status
  /// — used by the About page's "What's New", which is useful whether
  /// you're current or not.
  Future<AppReleaseInfo> fetchLatestRelease();
}

class GitHubReleaseUpdateService implements AppUpdateService {
  GitHubReleaseUpdateService({
    required this.repositoryOwner,
    required this.repositoryName,
  });

  final String repositoryOwner;
  final String repositoryName;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async {
    final release = await fetchLatestRelease();
    if (!release.isNewerThanInstalled) return null;

    return AppUpdateInfo(
      latestVersion: release.version,
      releaseUrl: release.releaseUrl,
      downloadUrl: release.downloadUrl,
    );
  }

  @override
  Future<AppReleaseInfo> fetchLatestRelease() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = packageInfo.buildNumber;
    final latestRelease = await _fetchLatestRelease();
    final latestVersion = _normalizeVersion(latestRelease.tagName);

    return AppReleaseInfo(
      version: latestVersion,
      releaseUrl: latestRelease.releaseUrl,
      downloadUrl: latestRelease.apkDownloadUrl ?? latestRelease.releaseUrl,
      releaseNotes: latestRelease.body,
      isNewerThanInstalled: _isNewerVersion(
        latestVersion,
        '$currentVersion+$currentBuildNumber',
      ),
    );
  }

  Future<_GitHubRelease> _fetchLatestRelease() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$repositoryOwner/$repositoryName/releases/latest',
      );
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'sbs-app');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub release check failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final assets = (json['assets'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      String? apkUrl;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String?;
        if (url != null && name.endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }

      return _GitHubRelease(
        tagName: json['tag_name'] as String? ?? '',
        releaseUrl: json['html_url'] as String? ?? '',
        apkDownloadUrl: apkUrl,
        body: (json['body'] as String? ?? '').trim(),
      );
    } finally {
      client.close();
    }
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String releaseUrl;
  final String downloadUrl;
}

/// Full info about the latest GitHub release, independent of whether it's
/// newer than what's installed — see [AppUpdateService.fetchLatestRelease].
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isNewerThanInstalled,
  });

  final String version;
  final String releaseUrl;
  final String downloadUrl;
  final String releaseNotes;
  final bool isNewerThanInstalled;
}

class _GitHubRelease {
  const _GitHubRelease({
    required this.tagName,
    required this.releaseUrl,
    required this.apkDownloadUrl,
    required this.body,
  });

  final String tagName;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final String body;
}

String _normalizeVersion(String version) {
  return version.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
}

bool _isNewerVersion(String latestVersion, String currentVersion) {
  final latest = _Version.parse(latestVersion);
  final current = _Version.parse(currentVersion);
  return latest.compareTo(current) > 0;
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.build);

  factory _Version.parse(String input) {
    final normalized = _normalizeVersion(input);
    final parts = normalized.split('+');
    final versionParts = parts.first.split('.');

    int valueAt(int index) {
      if (index >= versionParts.length) return 0;
      return int.tryParse(
            versionParts[index].replaceAll(RegExp(r'\D.*$'), ''),
          ) ??
          0;
    }

    return _Version(
      valueAt(0),
      valueAt(1),
      valueAt(2),
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int build;

  @override
  int compareTo(_Version other) {
    final comparisons = [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
      build.compareTo(other.build),
    ];

    return comparisons.firstWhere((value) => value != 0, orElse: () => 0);
  }
}
