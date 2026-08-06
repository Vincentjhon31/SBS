import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_providers.dart';
import 'approvals_providers.dart';

/// One release/return capture that has been taken on the phone but not
/// yet accepted by the server.
///
/// The photos are *not* held here — they're spooled to disk under
/// [photoPaths] the moment they're taken. A handoff photographed at a
/// barangay hall may sit in this queue for an hour before the approver
/// walks back into signal, and keeping five full-size JPEGs per capture
/// in memory across that window is how you get killed by the OS.
class QueuedEvidence {
  const QueuedEvidence({
    required this.id,
    required this.requestId,
    required this.itemLabel,
    required this.stage,
    required this.photoPaths,
    required this.queuedAt,
    this.notes,
    this.termsVersion,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String requestId;

  /// Only for showing the operator what's waiting — the server never
  /// sees this.
  final String itemLabel;

  /// 'release' or 'return'.
  final String stage;

  /// Absolute paths to the spooled JPEGs, in capture order.
  final List<String> photoPaths;

  final DateTime queuedAt;
  final String? notes;

  /// Release captures only — the liability terms version the borrower
  /// acknowledged at handoff, pinned at capture time so a later change to
  /// the terms can't rewrite what was agreed to.
  final String? termsVersion;

  final int attempts;

  /// Set when the server rejected this capture, so the UI can explain why
  /// it's stuck instead of retrying forever in silence.
  final String? lastError;

  bool get isRelease => stage == 'release';
  bool get isBlocked => lastError != null;

  QueuedEvidence copyWith({int? attempts, String? lastError}) =>
      QueuedEvidence(
        id: id,
        requestId: requestId,
        itemLabel: itemLabel,
        stage: stage,
        photoPaths: photoPaths,
        queuedAt: queuedAt,
        notes: notes,
        termsVersion: termsVersion,
        attempts: attempts ?? this.attempts,
        lastError: lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'item_label': itemLabel,
        'stage': stage,
        'photo_paths': photoPaths,
        'queued_at': queuedAt.toUtc().toIso8601String(),
        'notes': notes,
        'terms_version': termsVersion,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory QueuedEvidence.fromJson(Map<String, dynamic> json) => QueuedEvidence(
        id: json['id'] as String,
        requestId: json['request_id'] as String,
        itemLabel: json['item_label'] as String? ?? 'Item',
        stage: json['stage'] as String,
        photoPaths: (json['photo_paths'] as List).cast<String>(),
        queuedAt: DateTime.parse(json['queued_at'] as String).toLocal(),
        notes: json['notes'] as String?,
        termsVersion: json['terms_version'] as String?,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['last_error'] as String?,
      );
}

/// Store-and-forward for evidence captures.
///
/// The point of moving approvals onto a phone is that the approver walks
/// to the item instead of carrying the item to a laptop — which means
/// they're regularly somewhere with no signal. So the capture screen
/// never blocks on the network: photos land on disk here, the screen
/// closes as "done", and this drains the queue whenever connectivity
/// comes back.
///
/// Uploads are idempotent by construction — each photo goes to a fixed
/// `<requestId>/<stage>_<n>.jpg` path with upsert — so a retry after a
/// half-finished attempt overwrites rather than duplicating.
///
/// Web has no writable app directory, so there the queue stays empty and
/// captures submit straight through; the laptop that runs the dashboard
/// is on wired/office wifi anyway.
class EvidenceSyncQueue extends Notifier<List<QueuedEvidence>> {
  static const _prefsKey = 'sbs_evidence_queue';
  static const _spoolDir = 'evidence_queue';

  bool _flushing = false;

  @override
  List<QueuedEvidence> build() {
    // Drain automatically the moment the device is back on a network.
    ref.listen(isOnlineProvider, (was, now) {
      if (now && was != true) unawaited(flush());
    });
    unawaited(_restore());
    return const [];
  }

  bool get _supported => !kIsWeb;

  Future<Directory> _spool() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_spoolDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _restore() async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(QueuedEvidence.fromJson)
          .toList();
      // A capture whose spooled photos are gone (OS cleared app storage)
      // can never be sent — drop it rather than retrying forever.
      final surviving = <QueuedEvidence>[];
      for (final entry in decoded) {
        final intact = await Future.wait(
          [for (final p in entry.photoPaths) File(p).exists()],
        );
        if (intact.every((e) => e)) surviving.add(entry);
      }
      state = surviving;
      if (surviving.length != decoded.length) await _persist();
      unawaited(flush());
    } catch (e) {
      debugPrint('Evidence queue restore failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final e in state) e.toJson()]),
      );
    } catch (e) {
      debugPrint('Evidence queue persist failed: $e');
    }
  }

  /// Spools [photos] to disk and records the capture for later delivery.
  /// Throws if the device can't be written to, so the caller can fall
  /// back to reporting the original network failure instead of silently
  /// losing the handoff.
  Future<void> enqueue({
    required String requestId,
    required String itemLabel,
    required String stage,
    required List<Uint8List> photos,
    String? notes,
    String? termsVersion,
  }) async {
    if (!_supported) {
      throw UnsupportedError('Offline capture queue needs a native device.');
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}_$stage';
    final dir = Directory('${(await _spool()).path}/$id');
    await dir.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final file = File('${dir.path}/${i + 1}.jpg');
      await file.writeAsBytes(photos[i], flush: true);
      paths.add(file.path);
    }
    state = [
      ...state,
      QueuedEvidence(
        id: id,
        requestId: requestId,
        itemLabel: itemLabel,
        stage: stage,
        photoPaths: paths,
        queuedAt: DateTime.now(),
        notes: notes,
        termsVersion: termsVersion,
      ),
    ];
    await _persist();
    unawaited(flush());
  }

  /// Attempts to deliver everything waiting, oldest first. Safe to call
  /// at any time — concurrent calls collapse into one pass.
  Future<void> flush() async {
    if (!_supported || _flushing || state.isEmpty) return;
    if (!ref.read(isOnlineProvider)) return;
    _flushing = true;
    try {
      final repo = ref.read(approvalsRepositoryProvider);
      var delivered = false;
      // Snapshot: enqueue() during the pass appends to `state`, and those
      // late arrivals get picked up by the flush their own enqueue kicks
      // off rather than being iterated mid-loop.
      for (final entry in List<QueuedEvidence>.from(state)) {
        // A capture the server already refused is not retried on its own;
        // the operator has to look at it and choose to retry or discard.
        if (entry.isBlocked) continue;
        try {
          final photos = await Future.wait(
            [for (final p in entry.photoPaths) File(p).readAsBytes()],
          );
          if (entry.isRelease) {
            await repo.captureRelease(
              requestId: entry.requestId,
              photos: photos,
              termsVersion: entry.termsVersion ?? '',
              notes: entry.notes,
            );
          } else {
            await repo.captureReturn(
              requestId: entry.requestId,
              photos: photos,
              notes: entry.notes,
            );
          }
          await _remove(entry.id, deleteFiles: true);
          delivered = true;
        } on PostgrestException catch (e) {
          // The server was reached and said no — retrying changes
          // nothing, so park it with the reason attached.
          await _mark(entry.id, e.message);
        } catch (e) {
          // Transport-level: still offline, or dropped mid-upload. Leave
          // it queued and stop the pass; the next reconnect retries.
          await _bump(entry.id, e);
          break;
        }
      }
      if (delivered) ref.invalidate(approvalQueueProvider);
    } finally {
      _flushing = false;
    }
  }

  /// Clears the error on a parked capture so the next flush retries it.
  Future<void> retry(String id) async {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(lastError: null) else e,
    ];
    await _persist();
    unawaited(flush());
  }

  /// Throws the capture away, photos and all.
  Future<void> discard(String id) => _remove(id, deleteFiles: true);

  Future<void> _remove(String id, {required bool deleteFiles}) async {
    final matches = state.where((e) => e.id == id).toList();
    final entry = matches.isEmpty ? null : matches.first;
    state = [
      for (final e in state)
        if (e.id != id) e,
    ];
    await _persist();
    if (deleteFiles && entry != null) {
      try {
        final dir = Directory('${(await _spool()).path}/${entry.id}');
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (e) {
        debugPrint('Evidence spool cleanup failed for $id: $e');
      }
    }
  }

  Future<void> _mark(String id, String error) async {
    state = [
      for (final e in state)
        if (e.id == id)
          e.copyWith(attempts: e.attempts + 1, lastError: error)
        else
          e,
    ];
    await _persist();
  }

  /// Retry budget before a capture stops draining on its own. Transport
  /// errors normally clear themselves when signal returns, but something
  /// genuinely broken (a corrupt spool file, a bucket the account can no
  /// longer write to) would otherwise retry on every reconnect forever
  /// and never tell anyone. After this many tries it parks with its
  /// error, visible in Pending sync, for a human to retry or discard.
  static const _maxAttempts = 5;

  Future<void> _bump(String id, Object error) async {
    debugPrint('Evidence capture $id still pending: $error');
    state = [
      for (final e in state)
        if (e.id == id)
          e.copyWith(
            attempts: e.attempts + 1,
            lastError: e.attempts + 1 >= _maxAttempts ? '$error' : null,
          )
        else
          e,
    ];
    await _persist();
  }
}

final evidenceSyncQueueProvider =
    NotifierProvider<EvidenceSyncQueue, List<QueuedEvidence>>(
  EvidenceSyncQueue.new,
);

/// How many captures are waiting to reach the server — drives the badge
/// on the Approvals tab.
final pendingEvidenceCountProvider = Provider<int>(
  (ref) => ref.watch(evidenceSyncQueueProvider).length,
);
