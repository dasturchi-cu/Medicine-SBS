import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_controller.dart';

class CourseCardStats {
  const CourseCardStats({
    required this.ratingAvg,
    required this.ratingCount,
    required this.commentsCount,
  });

  final double ratingAvg;
  final int ratingCount;
  final int commentsCount;
}

final courseCardStatsProvider = StreamProvider.autoDispose.family<CourseCardStats, String>((
  ref,
  courseId,
) async* {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  final baseUrl = getApiBaseUrl();
  if (baseUrl.isEmpty || courseId.trim().isEmpty) {
    yield const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0);
    return;
  }

  Future<CourseCardStats> load() async {
    final hasUser = userId.trim().isNotEmpty;
    final uri = Uri.parse(
      hasUser
          ? '$baseUrl/api/v1/courses/$courseId/stats?user_id=$userId'
          : '$baseUrl/api/v1/courses/$courseId/stats',
    );
    debugPrint('[API][courses.card_stats][request] $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    debugPrint('[API][courses.card_stats][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Card stats xatolik (${response.statusCode}).');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Card stats JSON emas.');
    }
    return CourseCardStats(
      ratingAvg: double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0,
      ratingCount: int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0,
      commentsCount: int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0,
    );
  }

  CourseCardStats last = const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0);
  try {
    last = await load();
    yield last;
  } catch (_) {
    yield last;
  }

  await for (final _ in Stream.periodic(const Duration(seconds: 120))) {
    try {
      last = await load();
      yield last;
    } catch (_) {}
  }
});

final contentCardStatsProvider = StreamProvider.autoDispose.family<CourseCardStats, ({String key, bool useFeedbackApi})>((
  ref,
  args,
) async* {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  final baseUrl = getApiBaseUrl();
  final key = args.key.trim();
  if (baseUrl.isEmpty || key.isEmpty) {
    yield const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0);
    return;
  }

  Future<CourseCardStats> load() async {
    final hasUser = userId.trim().isNotEmpty;
    final path = args.useFeedbackApi
        ? (hasUser ? '/api/v1/feedback/$key/stats?user_id=$userId' : '/api/v1/feedback/$key/stats')
        : (hasUser ? '/api/v1/courses/$key/stats?user_id=$userId' : '/api/v1/courses/$key/stats');
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('[API][content.card_stats][request] $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    debugPrint('[API][content.card_stats][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Content card stats xatolik (${response.statusCode}).');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Content card stats JSON emas.');
    }
    return CourseCardStats(
      ratingAvg: double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0,
      ratingCount: int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0,
      commentsCount: int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0,
    );
  }

  CourseCardStats last = const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0);
  try {
    last = await load();
    yield last;
  } catch (_) {
    yield last;
  }

  await for (final _ in Stream.periodic(const Duration(seconds: 120))) {
    try {
      last = await load();
      yield last;
    } catch (_) {}
  }
});
