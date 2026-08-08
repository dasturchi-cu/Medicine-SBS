import '../models/notification_models.dart';

abstract class NotificationsRepository {
  Future<List<AppNotificationItem>> fetchFeed({required String userId});
  Future<void> markViewed({required String userId, required String notificationId});
  Future<void> markClicked({required String userId, required String notificationId});
  Stream<List<AppNotificationItem>> watchFeed({
    required String userId,
    Duration pollInterval = const Duration(seconds: 8),
  });
}
