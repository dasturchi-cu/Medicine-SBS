import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_asset_models.dart';
import 'books_repository.dart';

class HttpBooksRepository implements BooksRepository {
  HttpBooksRepository({
    required this.baseUrl,
    this.client,
  });

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  @override
  Future<List<BookItemModel>> fetchBooks({String? userId}) async {
    if (baseUrl.isEmpty) return const [];
    // user_id yuborilsa backend qulf/ochiqlikni (has_access) shu userga qarab hisoblaydi.
    final q = (userId != null && userId.isNotEmpty) ? '?user_id=$userId' : '';
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/content/books$q'));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(BookItemModel.fromJson).toList(growable: false);
  }

  @override
  Stream<List<BookItemModel>> watchBooks({String? userId, Duration pollInterval = const Duration(seconds: 10)}) {
    final controller = StreamController<List<BookItemModel>>();
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      controller.add(await fetchBooks(userId: userId));
    }

    Future<void> boot() async {
      await push();
      poller = Timer.periodic(pollInterval, (_) => unawaited(push()));
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<List<BookProgressModel>> fetchProgress({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const [];
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/content/books/progress?user_id=$userId'));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(BookProgressModel.fromJson).toList(growable: false);
  }

  @override
  Future<void> upsertProgress({
    required String userId,
    required String bookId,
    required int pageNo,
    required double progressPercent,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || bookId.isEmpty) return;
    await _client.post(
      Uri.parse('$baseUrl/api/v1/content/books/$bookId/progress'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'page_no': pageNo,
        'progress_percent': progressPercent,
      }),
    );
  }
}
