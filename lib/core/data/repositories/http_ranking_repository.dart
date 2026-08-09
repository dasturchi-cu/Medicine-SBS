import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ranking_models.dart';
import 'ranking_repository.dart';

class HttpRankingRepository implements RankingRepository {
  HttpRankingRepository({required this.baseUrl, this.client});

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
  Future<List<RankingItemModel>> fetchRanking({
    int limit = 50,
    String period = 'overall',
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception('API manzili topilmadi (ranking).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/ranking?limit=$limit&period=$period');
    debugPrint('[API][ranking.fetch][request] $uri');
    final response = await _client.get(uri);
    debugPrint('[API][ranking.fetch][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage("Reytingni olishda xatolik (${response.statusCode}).", response.body),
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Reyting javobi JSON emas.');
    }
    final raw = body['items'];
    if (raw is! List) {
      throw Exception("Reyting ro'yxati topilmadi.");
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RankingItemModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> recordStudy({required String userId, required int seconds}) async {
    if (baseUrl.isEmpty || userId.isEmpty || seconds <= 0) return;
    try {
      await _client.post(
        Uri.parse('$baseUrl/api/v1/ranking/study'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'seconds': seconds}),
      );
    } catch (error) {
      debugPrint('[API][ranking.study][error] $error');
    }
  }
}
