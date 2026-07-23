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
