import 'package:flutter_test/flutter_test.dart';
import 'package:sbs/core/offline/offline_cache.dart';
import 'package:sbs/features/approvals/data/approvals_models.dart';
import 'package:sbs/features/approvals/data/evidence_sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OfflineCache', () {
    test('round-trips the raw rows a query returned', () async {
      await OfflineCache.writeRows('approvals_pending', [
        {'id': 'a', 'status': 'pending'},
      ]);

      final cached = await OfflineCache.readRows('approvals_pending');

      expect(cached, isNotNull);
      expect(cached!.value.single['id'], 'a');
      // The stamp is what lets the UI say how stale the copy is, so it
      // has to survive the round trip rather than being regenerated.
      expect(
        cached.cachedAt.isAfter(DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        )),
        isTrue,
      );
    });

    test('reports a miss for a key that was never written', () async {
      expect(await OfflineCache.readRows('approvals_pending'), isNull);
    });

    test('clearAll drops cached queues but leaves other prefs alone', () async {
      SharedPreferences.setMockInitialValues({'sbs_view_mode': 'table'});
      await OfflineCache.writeRows('approvals_pending', [
        {'id': 'a'},
      ]);

      await OfflineCache.clearAll();

      expect(await OfflineCache.readRows('approvals_pending'), isNull);
      // Signing out must not also wipe the device's own settings.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sbs_view_mode'), 'table');
    });
  });

  group('QueuedEvidence', () {
    // The queue survives app restarts by writing itself to disk as JSON,
    // so a break in this round trip silently loses handoffs that were
    // already photographed.
    test('round-trips through JSON', () {
      final original = QueuedEvidence(
        id: '1700000000_release',
        requestId: 'req-1',
        itemLabel: 'Sound System (SS-02)',
        stage: 'release',
        photoPaths: const ['/spool/1.jpg', '/spool/2.jpg'],
        queuedAt: DateTime(2026, 8, 6, 14, 30),
        notes: 'existing scratch on the lid',
        termsVersion: 'v3',
        attempts: 2,
        lastError: 'row-level security',
      );

      final restored = QueuedEvidence.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.requestId, original.requestId);
      expect(restored.itemLabel, original.itemLabel);
      expect(restored.stage, original.stage);
      expect(restored.photoPaths, original.photoPaths);
      expect(restored.queuedAt, original.queuedAt);
      expect(restored.notes, original.notes);
      expect(restored.termsVersion, original.termsVersion);
      expect(restored.attempts, original.attempts);
      expect(restored.lastError, original.lastError);
      expect(restored.isRelease, isTrue);
      expect(restored.isBlocked, isTrue);
    });

    test('a return capture carries no terms version and is not blocked', () {
      final restored = QueuedEvidence.fromJson(
        QueuedEvidence(
          id: '2',
          requestId: 'req-2',
          itemLabel: 'Tent',
          stage: 'return',
          photoPaths: const ['/spool/1.jpg'],
          queuedAt: DateTime(2026, 8, 6),
        ).toJson(),
      );

      expect(restored.isRelease, isFalse);
      expect(restored.termsVersion, isNull);
      expect(restored.isBlocked, isFalse);
      expect(restored.attempts, 0);
    });

    test('copyWith clears lastError when retrying a parked capture', () {
      final parked = QueuedEvidence(
        id: '3',
        requestId: 'req-3',
        itemLabel: 'Chairs',
        stage: 'return',
        photoPaths: const ['/spool/1.jpg'],
        queuedAt: DateTime(2026, 8, 6),
        attempts: 5,
        lastError: 'timeout',
      );

      final retried = parked.copyWith(lastError: null);

      expect(retried.isBlocked, isFalse);
      // The attempt count is deliberately kept — clearing the error is a
      // retry, not a reset of the capture's history.
      expect(retried.attempts, 5);
    });
  });

  group('ApprovalQueue', () {
    test('is stale only when it came from the cache', () {
      expect(const ApprovalQueue(requests: []).isStale, isFalse);
      expect(
        ApprovalQueue(requests: const [], cachedAt: DateTime(2026, 8, 6))
            .isStale,
        isTrue,
      );
    });
  });
}
