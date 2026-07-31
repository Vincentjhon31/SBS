import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'approvals_models.dart';

/// Thrown when an approval collides with an existing approved reservation
/// (the DB exclusion constraint fired).
class ReservationConflictException implements Exception {}

/// Thrown when approving a citizen whose identity is not yet verified.
class CitizenNotVerifiedException implements Exception {}

class ApprovalsRepository {
  ApprovalsRepository(this._client);

  final SupabaseClient _client;

  /// Requests in the caller's approval scope. [statuses] is a
  /// comma-separated status list (e.g. 'released,overdue').
  Future<List<PendingApproval>> fetchQueue(String statuses) async {
    final rows = await _client
        .from('borrow_requests')
        .select('*, items(name, distinguishing_tag), '
            'profiles!borrow_requests_borrower_id_fkey(full_name, user_type), '
            'guest_borrowers(full_name)')
        .inFilter('status', statuses.split(','))
        .order('created_at', ascending: true);
    return [for (final row in rows) PendingApproval.fromJson(row)];
  }

  Future<CitizenVerification> fetchCitizenVerification(
      String borrowerId) async {
    final row = await _client
        .from('citizen_profiles')
        .select()
        .eq('id', borrowerId)
        .single();
    final photoPath = row['id_photo_path'] as String?;
    String? photoUrl;
    if (photoPath != null) {
      photoUrl = await _client.storage
          .from('id-photos')
          .createSignedUrl(photoPath, 600);
    }
    return CitizenVerification(
      contactNumber: row['contact_number'] as String,
      idType: row['id_type'] as String,
      idNumber: row['id_number'] as String,
      verified: row['verified'] as bool? ?? false,
      idPhotoUrl: photoUrl,
    );
  }

  Future<void> verifyCitizen(String borrowerId) =>
      _client.rpc('verify_citizen', params: {'citizen': borrowerId});

  Future<void> approve(String requestId) async {
    try {
      await _client
          .from('borrow_requests')
          .update({'status': 'approved'}).eq('id', requestId);
    } on PostgrestException catch (e) {
      if (e.code == '23P01') throw ReservationConflictException();
      if (e.message.contains('verified')) throw CitizenNotVerifiedException();
      rethrow;
    }
  }

  Future<void> reject(String requestId, String reason) async {
    await _client.from('borrow_requests').update({
      'status': 'rejected',
      'rejected_reason': reason.trim(),
    }).eq('id', requestId);
  }

  Future<String> _uploadEvidencePhoto(
    String requestId,
    String stage,
    int index,
    Uint8List bytes,
    String contentType,
  ) async {
    final path = '$requestId/${stage}_$index.jpg';
    await _client.storage.from('evidence-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<List<String>> _uploadEvidencePhotos(
    String requestId,
    String stage,
    List<Uint8List> photos,
    String contentType,
  ) async {
    final paths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      paths.add(await _uploadEvidencePhoto(
          requestId, stage, i + 1, photos[i], contentType));
    }
    return paths;
  }

  /// Uploads up to 5 photos, then atomically records evidence + liability
  /// acknowledgment + status flip via the release_item RPC.
  Future<void> captureRelease({
    required String requestId,
    required List<Uint8List> photos,
    required String termsVersion,
    String? notes,
    String contentType = 'image/jpeg',
  }) async {
    final paths =
        await _uploadEvidencePhotos(requestId, 'release', photos, contentType);
    await _client.rpc('release_item', params: {
      'req': requestId,
      'photos': paths,
      'acknowledged': true,
      'terms_version': termsVersion,
      'notes': notes,
    });
  }

  Future<void> captureReturn({
    required String requestId,
    required List<Uint8List> photos,
    String? notes,
    String contentType = 'image/jpeg',
  }) async {
    final paths =
        await _uploadEvidencePhotos(requestId, 'return', photos, contentType);
    await _client.rpc('return_item', params: {
      'req': requestId,
      'photos': paths,
      'notes': notes,
    });
  }

  Future<List<EvidenceRecord>> fetchEvidence(String requestId) async {
    final rows = await _client
        .from('borrow_evidence')
        .select()
        .eq('borrow_request_id', requestId)
        .order('captured_at', ascending: true);
    final storage = _client.storage.from('evidence-photos');
    final records = <EvidenceRecord>[];
    for (final row in rows) {
      final paths = (row['photo_paths'] as List).cast<String>();
      final urls = [
        for (final path in paths) await storage.createSignedUrl(path, 3600),
      ];
      records.add(EvidenceRecord(
        stage: row['stage'] as String,
        photoUrls: urls,
        conditionNotes: row['condition_notes'] as String?,
        capturedAt: DateTime.parse(row['captured_at'] as String).toLocal(),
      ));
    }
    return records;
  }
}
