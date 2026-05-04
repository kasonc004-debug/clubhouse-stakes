class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    this.payload = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
        id:        j['id'] as String,
        type:      j['type'] as String,
        title:     j['title'] as String,
        body:      j['body'] as String?,
        link:      j['link'] as String?,
        payload:   (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        readAt:    j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class NotificationsPage {
  final List<NotificationModel> notifications;
  final int unread;

  const NotificationsPage({required this.notifications, required this.unread});

  factory NotificationsPage.fromJson(Map<String, dynamic> j) => NotificationsPage(
        notifications: (j['notifications'] as List? ?? [])
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        unread: int.tryParse(j['unread']?.toString() ?? '0') ?? 0,
      );
}
