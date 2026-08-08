import 'package:flutter_riverpod/flutter_riverpod.dart';

class CourseComment {
  final String id;
  final String authorUz;
  final String textUz;
  final DateTime createdAt;

  const CourseComment({
    required this.id,
    required this.authorUz,
    required this.textUz,
    required this.createdAt,
  });
}

final courseCommentsProvider =
    NotifierProviderFamily<CourseCommentsController, List<CourseComment>, String>(
  CourseCommentsController.new,
);

class CourseCommentsController extends FamilyNotifier<List<CourseComment>, String> {
  @override
  List<CourseComment> build(String courseId) {
    return [
      CourseComment(
        id: '${courseId}_c1',
        authorUz: 'Dilshod',
        textUz: 'Zo‘r kurs, tushunarli.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      CourseComment(
        id: '${courseId}_c2',
        authorUz: 'Madina',
        textUz: 'Darslar ketma-ketligi juda yaxshi.',
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
    ];
  }

  void add({required String authorUz, required String textUz}) {
    final t = textUz.trim();
    if (t.isEmpty) return;
    state = [
      CourseComment(
        id: '${arg}_c${state.length + 1}',
        authorUz: authorUz,
        textUz: t,
        createdAt: DateTime.now(),
      ),
      ...state,
    ];
  }
}

