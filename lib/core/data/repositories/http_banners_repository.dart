import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/banner_models.dart';
import 'banners_repository.dart';

class HttpBannersRepository implements BannersRepository {
  HttpBannersRepository({
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
  Future<List<CourseBannerItem>> fetchBanners() async {
    if (baseUrl.isEmpty) {
      throw Exception('API manzili topilmadi (banners).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/banners?active_only=true');
    debugPrint('[API][banners.fetch][request] $uri');
    final response = await _client.get(uri);
    debugPrint('[API][banners.fetch][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bannerlarni olishda xatolik (${response.statusCode}).', response.body),
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Bannerlar javobi JSON emas.');
    }
    final rawItems = body['items'];
    if (rawItems is! List) {
      throw Exception("Bannerlar ro'yxati topilmadi.");
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(CourseBannerItem.fromJson)
        .toList(growable: false);
  }

  @override
  Stream<List<CourseBannerItem>> watchBanners({
    Duration pollInterval = const Duration(seconds: 8),
  }) async* {
    yield await fetchBanners();
    yield* Stream.periodic(pollInterval).asyncMap((_) => fetchBanners());
  }
}
