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
    this.useFrom,
    this.useTo,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemLabel;
  final String purpose;

  /// Availability window: [requestedFrom] = pickup, [requestedTo] = return.
  final DateTime requestedFrom;
  final DateTime requestedTo;
  final String status;
  final String? rejectedReason;
  final DateTime? dueAt;

  /// The event/use window — when the borrower actually uses the item.
  /// Null for legacy rows and walk-in loans (which are picked up on the
  /// spot with no advance planning).
  final DateTime? useFrom;
  final DateTime? useTo;
  final DateTime createdAt;

  factory BorrowRequest.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final name = item?['name'] as String? ?? 'Unknown item';
    final tag = item?['distinguishing_tag'] as String?;
    DateTime? parse(String key) => json[key] == null
        ? null
        : DateTime.parse(json[key] as String).toLocal();
    return BorrowRequest(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemLabel: (tag == null || tag.isEmpty) ? name : '$name ($tag)',
      purpose: json['purpose'] as String,
      requestedFrom: DateTime.parse(json['requested_from'] as String).toLocal(),
      requestedTo: DateTime.parse(json['requested_to'] as String).toLocal(),
      status: json['status'] as String,
      rejectedReason: json['rejected_reason'] as String?,
      dueAt: parse('due_at'),
      useFrom: parse('use_from'),
      useTo: parse('use_to'),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class ReservedWindow {
  const ReservedWindow({
    required this.from,
    required this.to,
    required this.quantityRequested,
  });

  final DateTime from;

  /// Null for an open-ended walk-in loan (no due date) — never ends, so it
  /// overlaps everything from [from] onward.
  final DateTime? to;
  final int quantityRequested;

  bool overlaps(DateTime start, DateTime end) =>
      start.isBefore(to ?? DateTime(9999)) && end.isAfter(from);

  factory ReservedWindow.fromJson(Map<String, dynamic> json) => ReservedWindow(
        from: DateTime.parse(json['reserved_from'] as String).toLocal(),
        to: json['reserved_to'] == null
            ? null
            : DateTime.parse(json['reserved_to'] as String).toLocal(),
        quantityRequested: json['quantity_requested'] as int? ?? 1,
      );
}
