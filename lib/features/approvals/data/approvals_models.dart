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
  });

  final String id;
  final String itemLabel;
  final String purpose;
  final DateTime requestedFrom;
  final DateTime requestedTo;
  final String borrowerId;
  final String borrowerName;
  final String borrowerType;
  final String status;
  final DateTime createdAt;

  bool get isCitizenBorrower => borrowerType == 'citizen';
  bool get isOverdue => status == 'overdue';

  factory PendingApproval.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final name = item?['name'] as String? ?? 'Unknown item';
    final tag = item?['distinguishing_tag'] as String?;
    final borrower = json['profiles'] as Map<String, dynamic>?;
    return PendingApproval(
      id: json['id'] as String,
      itemLabel: (tag == null || tag.isEmpty) ? name : '$name ($tag)',
      purpose: json['purpose'] as String,
      requestedFrom: DateTime.parse(json['requested_from'] as String).toLocal(),
      requestedTo: DateTime.parse(json['requested_to'] as String).toLocal(),
      borrowerId: json['borrower_id'] as String,
      borrowerName: borrower?['full_name'] as String? ?? 'Unknown borrower',
      borrowerType: json['borrower_type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.stage,
    required this.borrowerPhotoUrl,
    required this.itemPhotoUrl,
    this.conditionNotes,
    required this.capturedAt,
  });

  final String stage;
  final String borrowerPhotoUrl;
  final String itemPhotoUrl;
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
