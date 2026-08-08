import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/notification_models.dart';
import 'notifications_repository.dart';

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository({
    required this.baseUrl,
    this.client,
  });

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  String _errorMessage(String fallback, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Future<List<AppNotificationItem>> fetchFeed({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) {
      throw Exception('API manzili yoki userId topilmadi (notifications).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/feed?user_id=$userId&limit=100');
    debugPrint('[API][notifications.feed][request] $uri');
    final response = await _client.get(uri);
    debugPrint('[API][notifications.feed][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomalarni olishda xatolik (${response.statusCode}).', response.body),
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Bildirishnoma javobi JSON emas.');
    }
    final rawItems = body['items'];
    if (rawItems is! List) {
      throw Exception("Bildirishnoma ro'yxati topilmadi.");
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> markViewed({
    required String userId,
    required String notificationId,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || notificationId.isEmpty) {
      throw Exception('API manzili yoki identifikatorlar topilmadi (notifications.view).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/view');
    debugPrint('[API][notifications.view][request] $uri userId=$userId');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    debugPrint('[API][notifications.view][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomani ko‘rildi belgilashda xatolik (${response.statusCode}).', response.body),
      );
    }
  }

  @override
  Future<void> markClicked({
    required String userId,
    required String notificationId,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || notificationId.isEmpty) {
      throw Exception('API manzili yoki identifikatorlar topilmadi (notifications.click).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/click');
    debugPrint('[API][notifications.click][request] $uri userId=$userId');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    debugPrint('[API][notifications.click][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomani click belgilashda xatolik (${response.statusCode}).', response.body),
      );
    }
  }

  @override
  Stream<List<AppNotificationItem>> watchFeed({
    required String userId,
    Duration pollInterval = const Duration(seconds: 8),
  }) {
    if (userId.isEmpty) return Stream.value(const []);

    final controller = StreamController<List<AppNotificationItem>>();
    Timer? poller;
    var disposed = false;

    Future<void> publishLatest() async {
      if (disposed) return;
      try {
        final feed = await fetchFeed(userId: userId);
        if (!disposed) controller.add(feed);
      } catch (error, stackTrace) {
        if (!disposed) controller.addError(error, stackTrace);
      }
    }

    Future<void> bootstrap() async {
      await publishLatest();
      poller = Timer.periodic(pollInterval, (_) {
        unawaited(publishLatest());
      });
    }

    unawaited(bootstrap());

    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}
