class SuperadminStats {
  const SuperadminStats({
    required this.totalItems,
    required this.totalDepartments,
    required this.totalStaff,
    required this.totalCitizens,
    required this.verifiedCitizens,
    required this.unverifiedCitizens,
    required this.pendingRequests,
    required this.activeLoans,
    required this.overdueRequests,
    required this.pendingDeletionRequests,
  });

  final int totalItems;
  final int totalDepartments;
  final int totalStaff;
  final int totalCitizens;
  final int verifiedCitizens;
  final int unverifiedCitizens;
  final int pendingRequests;
  final int activeLoans;
  final int overdueRequests;
  final int pendingDeletionRequests;

  factory SuperadminStats.fromJson(Map<String, dynamic> json) {
    int i(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SuperadminStats(
      totalItems: i('total_items'),
      totalDepartments: i('total_departments'),
      totalStaff: i('total_staff'),
      totalCitizens: i('total_citizens'),
      verifiedCitizens: i('verified_citizens'),
      unverifiedCitizens: i('unverified_citizens'),
      pendingRequests: i('pending_requests'),
      activeLoans: i('active_loans'),
      overdueRequests: i('overdue_requests'),
      pendingDeletionRequests: i('pending_deletion_requests'),
    );
  }
}

class StaffMember {
  const StaffMember({required this.id, required this.fullName});

  final String id;
  final String fullName;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
      );
}

class DepartmentMembership {
  const DepartmentMembership({
    required this.id,
    required this.departmentId,
    required this.userId,
    required this.userFullName,
  });

  final String id;
  final String departmentId;
  final String userId;
  final String userFullName;

  factory DepartmentMembership.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return DepartmentMembership(
      id: json['id'] as String,
      departmentId: json['department_id'] as String,
      userId: json['user_id'] as String,
      userFullName: profile?['full_name'] as String? ?? 'Unknown',
    );
  }
}
