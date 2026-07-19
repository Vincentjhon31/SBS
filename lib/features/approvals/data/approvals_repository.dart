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

  Future<List<PendingApproval>> fetchPending() async {
    final rows = await _client
        .from('borrow_requests')
        .select('*, items(name, distinguishing_tag), '
            'profiles!borrow_requests_borrower_id_fkey(full_name, user_type)')
        .eq('status', 'pending')
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
}
