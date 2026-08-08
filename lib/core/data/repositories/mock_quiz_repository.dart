import '../../models/quiz_models.dart';
import 'quiz_repository.dart';

class MockQuizRepository implements QuizRepository {
  static const _defaultQuestions = <QuizQuestion>[
    QuizQuestion(
      id: 'q1',
      questionUz: 'Savol hali qo\'shilmagan',
      optionsUz: ['A', 'B', 'C', 'D'],
      correctIndex: 0,
    ),
  ];

  @override
  Quiz? getQuizById(String id) {
    return Quiz(
      id: id,
      titleUz: 'Test',
      questions: _defaultQuestions,
    );
  }
}

