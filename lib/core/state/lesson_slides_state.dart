import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/lesson_slide_models.dart';
import '../di/providers.dart';

final lessonSlidesProvider = StreamProvider.family<List<LessonSlideItem>, String>((ref, lessonId) {
  return ref.read(lessonSlidesRepositoryProvider).watchLessonSlides(lessonId: lessonId);
});
