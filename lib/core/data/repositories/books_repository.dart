import '../models/content_asset_models.dart';

abstract class BooksRepository {
  Future<List<BookItemModel>> fetchBooks();
  Stream<List<BookItemModel>> watchBooks({Duration pollInterval = const Duration(seconds: 10)});
  Future<List<BookProgressModel>> fetchProgress({required String userId});
  Future<void> upsertProgress({
    required String userId,
    required String bookId,
    required int pageNo,
    required double progressPercent,
  });
}
