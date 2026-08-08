import '../models/content_asset_models.dart';

abstract class LessonAssetsRepository {
  Future<List<LessonAssetModel>> fetchAssets({required String lessonId});
  Stream<List<LessonAssetModel>> watchAssets({
    required String lessonId,
    Duration pollInterval = const Duration(seconds: 10),
  });
  Future<void> upsertProgress({
    required String userId,
    required String assetId,
    required int pageNo,
    required double progressPercent,
  });
}
