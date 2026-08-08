import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_asset_models.dart';
import '../di/providers.dart';

final lessonAssetsProvider = StreamProvider.family<List<LessonAssetModel>, String>((ref, lessonId) {
  return ref.read(lessonAssetsRepositoryProvider).watchAssets(lessonId: lessonId);
});
