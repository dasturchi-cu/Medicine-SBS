import '../models/banner_models.dart';

abstract class BannersRepository {
  Future<List<CourseBannerItem>> fetchBanners();
  Stream<List<CourseBannerItem>> watchBanners({
    Duration pollInterval = const Duration(seconds: 8),
  });
}
