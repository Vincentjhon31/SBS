class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.borrowRequestId,
    this.readAt,
    required this.sentAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? borrowRequestId;
  final DateTime? readAt;
  final DateTime sentAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        borrowRequestId: json['borrow_request_id'] as String?,
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String).toLocal(),
        sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
      );
}
