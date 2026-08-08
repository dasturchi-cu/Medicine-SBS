class Quiz {
  final String id;
  final String titleUz;
  final List<QuizQuestion> questions;

  const Quiz({
    required this.id,
    required this.titleUz,
    required this.questions,
  });
}

class QuizQuestion {
  final String id;
  final String questionUz;
  final List<String> optionsUz; // 4 items
  final int correctIndex; // 0..3

  const QuizQuestion({
    required this.id,
    required this.questionUz,
    required this.optionsUz,
    required this.correctIndex,
  });
}

