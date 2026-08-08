import '../models/lesson_slide_models.dart';

abstract class LessonSlidesRepository {
  Future<List<LessonSlideItem>> fetchLessonSlides({required String lessonId});
  Stream<List<LessonSlideItem>> watchLessonSlides({
    required String lessonId,
    Duration pollInterval = const Duration(seconds: 8),
  });
}
