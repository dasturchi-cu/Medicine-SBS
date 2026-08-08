class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.sentAt,
    required this.viewed,
  });

  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final DateTime sentAt;
  final bool viewed;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawSentAt = (json['sent_at'] ?? '').toString();
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      sentAt: DateTime.tryParse(rawSentAt)?.toLocal() ?? DateTime.now(),
      viewed: json['viewed'] == true,
    );
  }
}
