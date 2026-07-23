import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> exportMyData() async {
    final result = await _client.rpc('export_my_data');
    return result as Map<String, dynamic>;
  }

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

  /// 'blue' | 'purple' — server-synced so it follows the user across devices.
  Future<void> updateThemeColor(String value) async {
    await _client
        .from('profiles')
        .update({'theme_color': value}).eq('id', _client.auth.currentUser!.id);
  }
}
