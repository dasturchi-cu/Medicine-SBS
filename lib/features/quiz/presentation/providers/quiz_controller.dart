import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/models/quiz_models.dart';

class QuizState {
  final Quiz quiz;
  final int index;
  final Map<String, int> answersByQuestionId; // questionId -> optionIndex
  final DateTime startedAt;

  const QuizState({
    required this.quiz,
    required this.index,
    required this.answersByQuestionId,
    required this.startedAt,
  });

  QuizQuestion get current => quiz.questions[index];

  int? selectedForCurrent() => answersByQuestionId[current.id];

  int get total => quiz.questions.length;

  int computeScore() {
    var correct = 0;
    for (final q in quiz.questions) {
      final picked = answersByQuestionId[q.id];
      if (picked != null && picked == q.correctIndex) correct++;
    }
    return ((correct / total) * 100).round();
  }

  int correctCount() {
    var correct = 0;
    for (final q in quiz.questions) {
      final picked = answersByQuestionId[q.id];
      if (picked != null && picked == q.correctIndex) correct++;
    }
    return correct;
  }

  double elapsedMinutes() {
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    return seconds <= 0 ? 0.0 : (seconds / 60);
  }

  QuizState copyWith({
    int? index,
    Map<String, int>? answersByQuestionId,
    DateTime? startedAt,
  }) {
    return QuizState(
      quiz: quiz,
      index: index ?? this.index,
      answersByQuestionId: answersByQuestionId ?? this.answersByQuestionId,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

final quizControllerProvider =
    NotifierProviderFamily<QuizController, QuizState?, String>(QuizController.new);

class QuizController extends FamilyNotifier<QuizState?, String> {
  @override
  QuizState? build(String arg) {
    final repo = ref.watch(quizRepositoryProvider);
    final quiz = repo.getQuizById(arg);
    if (quiz == null) return null;
    return QuizState(quiz: quiz, index: 0, answersByQuestionId: const {}, startedAt: DateTime.now());
  }

  void pick(int optionIndex) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      answersByQuestionId: {...s.answersByQuestionId, s.current.id: optionIndex},
    );
  }

  void next() {
    final s = state;
    if (s == null) return;
    if (s.index < s.quiz.questions.length - 1) {
      state = s.copyWith(index: s.index + 1);
    }
  }

  void reset() {
    final s = state;
    if (s == null) return;
    state = QuizState(quiz: s.quiz, index: 0, answersByQuestionId: const {}, startedAt: DateTime.now());
  }
}

