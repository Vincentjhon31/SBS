import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<SuperadminStats> fetchStats() async {
    final result = await _client.rpc('superadmin_stats');
    return SuperadminStats.fromJson(result as Map<String, dynamic>);
  }

  Future<DashboardTrends> fetchTrends() async {
    final result = await _client.rpc('superadmin_dashboard_trends');
    return DashboardTrends.fromJson(result as Map<String, dynamic>);
  }

  Future<List<StaffMember>> fetchAllStaff() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('user_type', 'staff')
        .order('full_name');
    return [for (final row in rows) StaffMember.fromJson(row)];
  }

  Future<List<DepartmentMembership>> fetchAllMemberships() async {
    final rows = await _client
        .from('department_members')
        .select('id, department_id, user_id, profiles(full_name)');
    return [for (final row in rows) DepartmentMembership.fromJson(row)];
  }

  Future<void> assignStaffToDepartment({
    required String departmentId,
    required String userId,
  }) async {
    await _client.from('department_members').insert({
      'department_id': departmentId,
      'user_id': userId,
      'role': 'approver',
    });
  }

  Future<void> removeMembership(String membershipId) async {
    await _client.from('department_members').delete().eq('id', membershipId);
  }

  // ── Users management ──────────────────────────────────────────────

  Future<List<UserAccount>> fetchAllUsers() async {
    final rows = await _client
        .from('profiles')
        .select(
          'id, full_name, username, user_type, is_superadmin, active, '
          'citizen_profiles!citizen_profiles_id_fkey(verified)',
        )
        .order('full_name');
    return [for (final row in rows) UserAccount.fromJson(row)];
  }

  Future<void> setCitizenVerified(String citizenId, bool verified) =>
      _client.rpc(
        'set_citizen_verified',
        params: {'p_citizen_id': citizenId, 'p_verified': verified},
      );

  Future<void> setUserType(String userId, String userType) => _client.rpc(
    'set_user_type',
    params: {'p_user_id': userId, 'p_user_type': userType},
  );

  Future<void> setSuperadmin(String userId, bool isSuperadmin) => _client.rpc(
    'set_superadmin',
    params: {'p_user_id': userId, 'p_is_superadmin': isSuperadmin},
  );

  Future<void> setAccountActive(String userId, bool active) => _client.rpc(
    'set_account_active',
    params: {'p_user_id': userId, 'p_active': active},
  );

  // ── Audit log ──────────────────────────────────────────────────────

  Future<List<AuditLogEntry>> fetchAuditLog() async {
    final rows = await _client
        .from('audit_log')
        .select('id, action, target_type, target_id, detail, created_at, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final row in rows) AuditLogEntry.fromJson(row)];
  }

  // ── Broadcast announcements ───────────────────────────────────────

  Future<void> broadcastAnnouncement({
    required String title,
    required String body,
  }) => _client.rpc(
    'broadcast_announcement',
    params: {'p_title': title, 'p_body': body},
  );

  // ── App settings ───────────────────────────────────────────────────

  Future<Map<String, String>> fetchAppSettings() async {
    final rows = await _client.from('app_settings').select('key, value');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  Future<void> setAppSetting(String key, String value) => _client.rpc(
    'set_app_setting',
    params: {'p_key': key, 'p_value': value},
  );
}
