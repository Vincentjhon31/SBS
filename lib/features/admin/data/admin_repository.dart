import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<SuperadminStats> fetchStats() async {
    final result = await _client.rpc('superadmin_stats');
    return SuperadminStats.fromJson(result as Map<String, dynamic>);
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
}
