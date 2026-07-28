import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  Future<ConsentInfo?> myConsentInfo() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('citizen_profiles')
        .select('consented_at, verified')
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : ConsentInfo.fromJson(row);
  }

  Future<DeletionRequest?> myDeletionRequest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('data_deletion_requests')
        .select()
        .eq('user_id', uid)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : DeletionRequest.fromJson(row);
  }

  Future<void> requestDeletion(String? reason) async {
    await _client.from('data_deletion_requests').insert({
      'user_id': _client.auth.currentUser!.id,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  /// Staff-only (enforced by RLS).
  Future<List<DeletionRequest>> pendingDeletionRequests() async {
    final rows = await _client
        .from('data_deletion_requests')
        .select('*, profiles!data_deletion_requests_user_id_fkey(full_name)')
        .eq('status', 'pending')
        .order('requested_at', ascending: true);
    return [for (final row in rows) DeletionRequest.fromJson(row)];
  }

  Future<void> completeDeletionRequest(String id) =>
      _client.rpc('complete_deletion_request', params: {'request_id': id});

  /// 'blue' | 'purple' | 'teal' | 'coral' | 'green' — server-synced so it
  /// follows the user across devices.
  Future<void> updateThemeColor(String value) async {
    await _client
        .from('profiles')
        .update({'theme_color': value}).eq('id', _client.auth.currentUser!.id);
  }

  /// 'glossy' | 'blob' | 'solid' — server-synced so it follows the user
  /// across devices (mirrors [updateThemeColor]).
  Future<void> updateBackgroundStyle(String value) async {
    await _client
        .from('profiles')
        .update({'background_style': value}).eq(
      'id',
      _client.auth.currentUser!.id,
    );
  }

  Future<MyProfileInfo?> myProfileInfo() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('citizen_profiles')
        .select('contact_number, id_type, id_number, address, verified')
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : MyProfileInfo.fromJson(row);
  }

  Future<void> updateFullName(String name) async {
    await _client
        .from('profiles')
        .update({'full_name': name.trim()}).eq(
      'id',
      _client.auth.currentUser!.id,
    );
  }

  Future<void> updateCitizenContactInfo({
    String? contactNumber,
    String? address,
  }) async {
    final updates = <String, dynamic>{
      if (contactNumber != null) 'contact_number': contactNumber.trim(),
      if (address != null) 'address': address.trim(),
    };
    if (updates.isEmpty) return;
    await _client
        .from('citizen_profiles')
        .update(updates)
        .eq('id', _client.auth.currentUser!.id);
  }

  /// Supabase sends a confirmation link to the new address before the
  /// change actually takes effect.
  Future<void> changeEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  /// Re-authenticates with [currentPassword] first — `updateUser` alone
  /// would let anyone with a still-open session change the password with
  /// no proof they know the current one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw StateError('No signed-in user email to re-authenticate with.');
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
