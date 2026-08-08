import '../../models/quiz_models.dart';
import 'quiz_repository.dart';

class HttpQuizRepository implements QuizRepository {
  @override
  Quiz? getQuizById(String id) {
    // Quiz data is served through real backend endpoints in quiz page flow.
    // This repository intentionally does not provide mock fallback data.
    return null;
  }
}
