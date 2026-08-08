import '../models/slide_models.dart';

abstract class SlidesRepository {
  Future<List<HomeSlideItem>> fetchSlides();
  Stream<List<HomeSlideItem>> watchSlides({
    Duration pollInterval = const Duration(seconds: 8),
  });
}
