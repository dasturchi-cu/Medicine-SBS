import '../../models/course_models.dart';

abstract class CourseRepository {
  List<Course> getCourses();
  Course? getCourseById(String id);
  Lesson? getLessonById(String lessonId);
  Section? getSectionById(String courseId, String sectionId);
  String? getCourseIdForLesson(String lessonId);
  String? getNextLessonId(String courseId, String lessonId);
  Lesson? getFirstUnlockedLesson(String courseId);
  List<Lesson> getFlattenLessons(String courseId);
}

