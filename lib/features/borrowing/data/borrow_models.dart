class BorrowRequest {
  const BorrowRequest({
    required this.id,
    required this.itemId,
    required this.itemLabel,
    required this.purpose,
    required this.requestedFrom,
    required this.requestedTo,
    required this.status,
    this.rejectedReason,
    this.dueAt,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemLabel;
  final String purpose;
  final DateTime requestedFrom;
  final DateTime requestedTo;
  final String status;
  final String? rejectedReason;
  final DateTime? dueAt;
  final DateTime createdAt;

  factory BorrowRequest.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final name = item?['name'] as String? ?? 'Unknown item';
    final tag = item?['distinguishing_tag'] as String?;
    return BorrowRequest(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemLabel: (tag == null || tag.isEmpty) ? name : '$name ($tag)',
      purpose: json['purpose'] as String,
      requestedFrom: DateTime.parse(json['requested_from'] as String).toLocal(),
      requestedTo: DateTime.parse(json['requested_to'] as String).toLocal(),
      status: json['status'] as String,
      rejectedReason: json['rejected_reason'] as String?,
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class ReservedWindow {
  const ReservedWindow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  bool overlaps(DateTime start, DateTime end) =>
      start.isBefore(to) && end.isAfter(from);

  factory ReservedWindow.fromJson(Map<String, dynamic> json) => ReservedWindow(
        from: DateTime.parse(json['reserved_from'] as String).toLocal(),
        to: DateTime.parse(json['reserved_to'] as String).toLocal(),
      );
}
