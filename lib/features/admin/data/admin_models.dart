/// A row in the admin Users management screen — every profile in the
/// system (citizens + staff), with the fields staff need to act on it.
class UserAccount {
  const UserAccount({
    required this.id,
    required this.fullName,
    required this.username,
    required this.userType,
    required this.isSuperadmin,
    required this.active,
    required this.verified,
  });

  final String id;
  final String fullName;
  final String? username;
  final String userType;
  final bool isSuperadmin;
  final bool active;

  /// Citizen ID-verification status; null for staff (no citizen_profiles
  /// row).
  final bool? verified;

  bool get isStaff => userType == 'staff';

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final citizenProfile = json['citizen_profiles'] as Map<String, dynamic>?;
    return UserAccount(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String?,
      userType: json['user_type'] as String,
      isSuperadmin: json['is_superadmin'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      verified: citizenProfile?['verified'] as bool?,
    );
  }
}

/// A single audit-log entry — see the Users screen's "Activity log" view.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.detail,
    required this.createdAt,
  });

  final String id;
  final String? actorName;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> detail;
  final DateTime createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['profiles'] as Map<String, dynamic>?;
    return AuditLogEntry(
      id: json['id'] as String,
      actorName: actor?['full_name'] as String?,
      action: json['action'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String?,
      detail: (json['detail'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

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

class DailyRequestCount {
  const DailyRequestCount({required this.day, required this.count});

  final DateTime day;
  final int count;

  factory DailyRequestCount.fromJson(Map<String, dynamic> json) =>
      DailyRequestCount(
        day: DateTime.parse(json['day'] as String),
        count: (json['count'] as num).toInt(),
      );
}

class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;

  factory StatusCount.fromJson(Map<String, dynamic> json) => StatusCount(
        status: json['status'] as String,
        count: (json['count'] as num).toInt(),
      );
}

class CategoryCount {
  const CategoryCount({required this.category, required this.count});

  final String category;
  final int count;

  factory CategoryCount.fromJson(Map<String, dynamic> json) => CategoryCount(
        category: json['category'] as String,
        count: (json['count'] as num).toInt(),
      );
}

class RecentActivityItem {
  const RecentActivityItem({
    required this.id,
    required this.itemName,
    required this.status,
    required this.createdAt,
    required this.isGuest,
    required this.borrowerName,
  });

  final String id;
  final String itemName;
  final String status;
  final DateTime createdAt;
  final bool isGuest;
  final String borrowerName;

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) =>
      RecentActivityItem(
        id: json['id'] as String,
        itemName: json['item_name'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isGuest: json['is_guest'] as bool,
        borrowerName: json['borrower_name'] as String,
      );
}

class DashboardTrends {
  const DashboardTrends({
    required this.dailyRequests,
    required this.requestsByStatus,
    required this.topCategories,
    required this.recentActivity,
  });

  final List<DailyRequestCount> dailyRequests;
  final List<StatusCount> requestsByStatus;
  final List<CategoryCount> topCategories;
  final List<RecentActivityItem> recentActivity;

  factory DashboardTrends.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        [for (final row in (json[key] as List)) parse(row as Map<String, dynamic>)];
    return DashboardTrends(
      dailyRequests: list('daily_requests', DailyRequestCount.fromJson),
      requestsByStatus: list('requests_by_status', StatusCount.fromJson),
      topCategories: list('top_categories', CategoryCount.fromJson),
      recentActivity: list('recent_activity', RecentActivityItem.fromJson),
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
