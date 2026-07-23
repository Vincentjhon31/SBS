import 'package:supabase_flutter/supabase_flutter.dart';

import 'borrow_models.dart';

class BorrowRepository {
  BorrowRepository(this._client);

  final SupabaseClient _client;

  Future<List<BorrowRequest>> fetchMyRequests() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('borrow_requests')
        .select('*, items(name, distinguishing_tag)')
        .eq('borrower_id', uid)
        .order('created_at', ascending: false);
    return [for (final row in rows) BorrowRequest.fromJson(row)];
  }

  Future<void> createRequest({
    required String itemId,
    required DateTime from,
    required DateTime to,
    required String purpose,
  }) async {
    await _client.from('borrow_requests').insert({
      'item_id': itemId,
      'borrower_id': _client.auth.currentUser!.id,
      // borrower_type is normalized by a DB trigger; value here is ignored.
      'borrower_type': 'citizen',
      'purpose': purpose.trim(),
      'requested_from': from.toUtc().toIso8601String(),
      'requested_to': to.toUtc().toIso8601String(),
    });
  }

  /// Approved/released windows for an item — no borrower identity exposed.
  Future<List<ReservedWindow>> fetchReservedWindows(String itemId) async {
    final rows = await _client
        .rpc('item_reserved_windows', params: {'item': itemId}) as List;
    return [
      for (final row in rows)
        ReservedWindow.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Walk-in counter flow: staff creates the guest identity and the
  /// request in one atomic step, pre-approved since staff is physically
  /// present. Returns the new borrow_requests id, ready for evidence
  /// capture (release_item) right away.
  Future<String> createGuestRequest({
    required String itemId,
    required String fullName,
    required String address,
    required String contactNumber,
    String? email,
    required String purpose,
    required DateTime from,
    DateTime? to,
    required bool consented,
  }) async {
    final result = await _client.rpc('create_guest_borrow_request', params: {
      'item': itemId,
      'full_name': fullName.trim(),
      'address': address.trim(),
      'contact_number': contactNumber.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'purpose': purpose.trim(),
      'requested_from': from.toUtc().toIso8601String(),
      'requested_to': to?.toUtc().toIso8601String(),
      'consented': consented,
    });
    return result as String;
  }
}
