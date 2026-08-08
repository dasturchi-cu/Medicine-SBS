import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notification_models.dart';
import '../di/providers.dart';
import 'auth_controller.dart';

final notificationsFeedProvider = StreamProvider<List<AppNotificationItem>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  return ref.read(notificationsRepositoryProvider).watchFeed(userId: userId);
});
