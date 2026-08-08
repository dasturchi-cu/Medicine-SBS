import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/comment_models.dart';
import 'comments_repository.dart';

class HttpCommentsRepository implements CommentsRepository {
  HttpCommentsRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();
  static const _timeout = Duration(seconds: 8);

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
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty) return const [];
    final hasUser = userId.trim().isNotEmpty;
    final uri = Uri.parse(
      hasUser
          ? '$baseUrl/api/v1/comments?course_key=$courseKey&user_id=$userId'
          : '$baseUrl/api/v1/comments?course_key=$courseKey',
    );
    debugPrint('[API][comments.fetch][request] courseKey=$courseKey userId=${hasUser ? userId : "-"}');
    final response = await _client.get(uri).timeout(_timeout);
    debugPrint('[API][comments.fetch][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Izohlarni olishda xatolik (${response.statusCode}).', response.body));
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception("Izohlar javobi noto'g'ri.");
    }
    final raw = body['items'];
    if (raw is! List) {
      throw Exception("Izohlar ro'yxati topilmadi.");
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AppCommentItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> addComment({
    required String courseKey,
    required String userId,
    required String authorName,
    required String text,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty || userId.isEmpty) return;
    debugPrint('[API][comments.add][request] courseKey=$courseKey userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments');
    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'course_key': courseKey,
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      }),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.add][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Izoh yuborilmadi (${response.statusCode}).', response.body));
    }
  }

  @override
  Future<void> addReply({
    required String commentId,
    required String userId,
    required String authorName,
    required String text,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    debugPrint('[API][comments.reply][request] commentId=$commentId userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/reply');
    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      }),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.reply][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Javob yuborilmadi (${response.statusCode}).', response.body));
    }
  }

  @override
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    debugPrint('[API][comments.like][request] commentId=$commentId userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/like');
    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.like][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Like amalida xatolik (${response.statusCode}).', response.body));
    }
  }

  @override
  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 15),
  }) {
    final controller = StreamController<List<AppCommentItem>>();
    Timer? poller;
    var disposed = false;
    List<AppCommentItem> last = const [];

    Future<void> push() async {
      if (disposed) return;
      try {
        last = await fetchComments(courseKey: courseKey, userId: userId);
      } catch (_) {}
      if (!disposed) controller.add(last);
    }

    Future<void> boot() async {
      await push();
      final pollMs = pollInterval.inMilliseconds;
      poller = Timer.periodic(Duration(milliseconds: pollMs.clamp(12000, 120000)), (_) => unawaited(push()));
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      await controller.close();
    };
    return controller.stream;
  }
}
