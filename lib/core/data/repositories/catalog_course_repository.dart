import '../../models/course_models.dart';
import '../../services/catalog_service.dart';
import 'course_repository.dart';

/// Reads the live catalog loaded from `GET /api/v1/mobile/courses` ([CatalogService]).
class CatalogCourseRepository implements CourseRepository {
  @override
  List<Course> getCourses() => CatalogService.courses;

  @override
  Course? getCourseById(String id) {
    for (final c in CatalogService.courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Lesson? getLessonById(String lessonId) {
    for (final c in CatalogService.courses) {
      for (final s in c.sections) {
        for (final l in s.lessons) {
          if (l.id == lessonId) return l;
        }
      }
    }
    return null;
  }

  @override
  String? getCourseIdForLesson(String lessonId) {
    for (final c in CatalogService.courses) {
      for (final s in c.sections) {
        for (final l in s.lessons) {
          if (l.id == lessonId) return c.id;
        }
      }
    }
    return null;
  }

  @override
  Section? getSectionById(String courseId, String sectionId) {
    final course = getCourseById(courseId);
    if (course == null) return null;
    for (final s in course.sections) {
      if (s.id == sectionId) return s;
    }
    return null;
  }

  @override
  String? getNextLessonId(String courseId, String lessonId) {
    final course = getCourseById(courseId);
    if (course == null) return null;
    final flat = <String>[];
    for (final s in course.sections) {
      for (final l in s.lessons) {
        flat.add(l.id);
      }
    }
    final idx = flat.indexOf(lessonId);
    if (idx < 0) return null;
    if (idx + 1 >= flat.length) return null;
    return flat[idx + 1];
  }

  @override
  Lesson? getFirstUnlockedLesson(String courseId) {
    final course = getCourseById(courseId);
    if (course == null) return null;
    for (final s in course.sections) {
      for (final l in s.lessons) {
        if (!l.isLocked) return l;
      }
    }
    return null;
  }

  @override
  List<Lesson> getFlattenLessons(String courseId) {
    final course = getCourseById(courseId);
    if (course == null) return const [];
    final flat = <Lesson>[];
    for (final s in course.sections) {
      flat.addAll(s.lessons);
    }
    return flat;
  }
}
