class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.reason,
    this.requesterName,
  });

  final String id;

  /// 'pending' | 'completed'
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? reason;

  /// Present only when fetched by staff (joined from profiles).
  final String? requesterName;

  factory DeletionRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['profiles'] as Map<String, dynamic>?;
    return DeletionRequest(
      id: json['id'] as String,
      status: json['status'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String).toLocal(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String).toLocal(),
      reason: json['reason'] as String?,
      requesterName: requester?['full_name'] as String?,
    );
  }
}

class ConsentInfo {
  const ConsentInfo({required this.consentedAt, required this.verified});

  final DateTime consentedAt;
  final bool verified;

  factory ConsentInfo.fromJson(Map<String, dynamic> json) => ConsentInfo(
        consentedAt: DateTime.parse(json['consented_at'] as String).toLocal(),
        verified: json['verified'] as bool? ?? false,
      );
}
