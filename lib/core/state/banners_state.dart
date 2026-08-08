import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/banner_models.dart';
import '../di/providers.dart';

final bannersFeedProvider = StreamProvider<List<CourseBannerItem>>((ref) {
  return ref.read(bannersRepositoryProvider).watchBanners();
});
