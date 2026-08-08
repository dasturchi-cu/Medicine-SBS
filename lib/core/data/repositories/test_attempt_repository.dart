abstract class TestAttemptRepository {
  Future<void> submitAttempt({
    required String quizId,
    required String userId,
    required double scorePercent,
    required int correctCount,
    required int totalQuestions,
    required double durationMinutes,
  });
}
