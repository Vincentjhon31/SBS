import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A previously-fetched payload plus when it was stored, so screens can
/// say *how stale* the copy they're showing is rather than silently
/// presenting old data as current.
class CachedPayload<T> {
  const CachedPayload({required this.value, required this.cachedAt});

  final T value;
  final DateTime cachedAt;
}

/// Last-known-good copies of read-only query results, kept in
/// SharedPreferences so an approver in a basement stockroom still sees
/// their queue instead of an error page.
///
/// Deliberately dumb: it stores the raw JSON rows the server returned,
/// not parsed models, so adding a field to a model doesn't invalidate
/// every cached entry — the same `fromJson` runs over cached rows as over
/// fresh ones. Anything unparseable is simply dropped, and the caller
/// falls back to showing the network error.
///
/// Not for writes. Anything that has to reach the server goes through a
/// queue that can retry (see the evidence sync queue), never through here.
abstract final class OfflineCache {
  static const _prefix = 'sbs_cache_';
  static const _stampSuffix = '_at';

  static Future<void> writeRows(String key, List<dynamic> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(rows));
      await prefs.setString(
        '$_prefix$key$_stampSuffix',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      // A cache write failing must never fail the read that triggered it.
      debugPrint('OfflineCache write failed for $key: $e');
    }
  }

  static Future<CachedPayload<List<Map<String, dynamic>>>?> readRows(
    String key,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final stamp = prefs.getString('$_prefix$key$_stampSuffix');
      return CachedPayload(
        value: decoded,
        cachedAt: stamp == null
            ? DateTime.now().toUtc()
            : DateTime.parse(stamp),
      );
    } catch (e) {
      debugPrint('OfflineCache read failed for $key: $e');
      return null;
    }
  }

  /// Drops every cached query. Called on sign-out so the next account on
  /// a shared device never sees the previous approver's queue.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('OfflineCache clear failed: $e');
    }
  }
}
