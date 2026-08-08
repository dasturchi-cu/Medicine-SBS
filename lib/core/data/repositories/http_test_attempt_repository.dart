import 'dart:convert';

import 'package:http/http.dart' as http;

import 'test_attempt_repository.dart';

class HttpTestAttemptRepository implements TestAttemptRepository {
  HttpTestAttemptRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  @override
  Future<void> submitAttempt({
    required String quizId,
    required String userId,
    required double scorePercent,
    required int correctCount,
    required int totalQuestions,
    required double durationMinutes,
  }) async {
    if (baseUrl.isEmpty || quizId.isEmpty || userId.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/tests/$quizId/attempts');
    await _client.post(
      uri,
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "score_percent": scorePercent,
        "correct_count": correctCount,
        "total_questions": totalQuestions,
        "duration_minutes": durationMinutes,
      }),
    );
  }
}
