class PendingApproval {
  const PendingApproval({
    required this.id,
    required this.itemLabel,
    required this.purpose,
    required this.requestedFrom,
    required this.requestedTo,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerType,
    required this.status,
    required this.createdAt,
    this.useFrom,
    this.useTo,
    this.rejectedReason,
    this.quantityRequested = 1,
    this.itemQuantity = 1,
  });

  final String id;
  final String itemLabel;
  final String purpose;

  /// How many units this request claims, out of [itemQuantity] the item
  /// has in total — "3 of 5 units", shown so staff know how many to
  /// release/return together.
  final int quantityRequested;
  final int itemQuantity;

  /// Availability window: [requestedFrom] = pickup, [requestedTo] = return.
  final DateTime requestedFrom;

  /// Null for an open-ended walk-in loan (borrowerType == 'guest' only).
  final DateTime? requestedTo;

  /// The event/use window — when the borrower actually uses the item.
  /// Null for walk-ins and legacy rows.
  final DateTime? useFrom;
  final DateTime? useTo;

  /// Null for a walk-in guest — there's no profiles row to reference.
  final String? borrowerId;
  final String borrowerName;
  final String borrowerType;
  final String status;
  final DateTime createdAt;

  /// Set only when [status] == 'rejected'.
  final String? rejectedReason;

  bool get isCitizenBorrower => borrowerType == 'citizen';
  bool get isGuestBorrower => borrowerType == 'guest';
  bool get isOverdue => status == 'overdue';

  factory PendingApproval.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final name = item?['name'] as String? ?? 'Unknown item';
    final tag = item?['distinguishing_tag'] as String?;
    final itemQuantity = item?['quantity'] as int? ?? 1;
    final borrower = json['profiles'] as Map<String, dynamic>?;
    final guest = json['guest_borrowers'] as Map<String, dynamic>?;
    return PendingApproval(
      id: json['id'] as String,
      itemLabel: (tag == null || tag.isEmpty) ? name : '$name ($tag)',
      purpose: json['purpose'] as String,
      requestedFrom: DateTime.parse(json['requested_from'] as String).toLocal(),
      requestedTo: json['requested_to'] == null
          ? null
          : DateTime.parse(json['requested_to'] as String).toLocal(),
      useFrom: json['use_from'] == null
          ? null
          : DateTime.parse(json['use_from'] as String).toLocal(),
      useTo: json['use_to'] == null
          ? null
          : DateTime.parse(json['use_to'] as String).toLocal(),
      borrowerId: json['borrower_id'] as String?,
      borrowerName: borrower?['full_name'] as String? ??
          guest?['full_name'] as String? ??
          'Unknown borrower',
      borrowerType: json['borrower_type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      rejectedReason: json['rejected_reason'] as String?,
      quantityRequested: json['quantity_requested'] as int? ?? 1,
      itemQuantity: itemQuantity,
    );
  }
}

/// One approvals tab's worth of requests, plus where they came from.
///
/// The queue is the one screen an approver may well be looking at with no
/// signal — a stockroom, a barangay hall, the back of a truck — so a
/// failed fetch falls back to the last copy on disk rather than an error.
/// [cachedAt] is what lets the UI be honest about that: null means these
/// rows came from the server just now, non-null means they're a snapshot
/// from that moment.
class ApprovalQueue {
  const ApprovalQueue({required this.requests, this.cachedAt});

  final List<PendingApproval> requests;
  final DateTime? cachedAt;

  bool get isStale => cachedAt != null;
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.stage,
    required this.photoUrls,
    this.conditionNotes,
    required this.capturedAt,
  });

  final String stage;

  /// Up to 5 photos, in capture order — no borrower/item distinction.
  final List<String> photoUrls;
  final String? conditionNotes;
  final DateTime capturedAt;
}

/// Router payload for the capture screen.
class EvidenceCaptureArgs {
  const EvidenceCaptureArgs({required this.request, required this.stage});

  final PendingApproval request;

  /// 'release' or 'return'.
  final String stage;
}

/// Router payload for the evidence viewer.
class EvidenceViewArgs {
  const EvidenceViewArgs({
    required this.requestId,
    required this.itemLabel,
  });

  final String requestId;
  final String itemLabel;
}

class CitizenVerification {
  const CitizenVerification({
    required this.contactNumber,
    required this.idType,
    required this.idNumber,
    required this.verified,
    this.idPhotoUrl,
  });

  final String contactNumber;
  final String idType;
  final String idNumber;
  final bool verified;
  final String? idPhotoUrl;
}
