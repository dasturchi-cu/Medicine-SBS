import '../../models/quiz_models.dart';

abstract class QuizRepository {
  Quiz? getQuizById(String id);
}

