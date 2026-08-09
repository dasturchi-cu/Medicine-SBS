import '../models/ranking_models.dart';

abstract class RankingRepository {
  /// [period]: daily | weekly | monthly | yearly | overall
  /// [source]: null (hammasi) | video | pomodoro
  Future<List<RankingItemModel>> fetchRanking({
    int limit = 50,
    String period = 'overall',
    String? source,
  });

  /// Pomodoro/o'qish vaqtini reytingga qo'shadi. [source]: video | pomodoro
  Future<void> recordStudy({
    required String userId,
    required int seconds,
    String source = 'pomodoro',
  });
}
