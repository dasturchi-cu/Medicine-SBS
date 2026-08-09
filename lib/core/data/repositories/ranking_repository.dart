import '../models/ranking_models.dart';

abstract class RankingRepository {
  /// [period]: daily | weekly | monthly | yearly | overall
  Future<List<RankingItemModel>> fetchRanking({
    int limit = 50,
    String period = 'overall',
  });

  /// Pomodoro/o'qish vaqtini reytingga qo'shadi (kunlik yangilanadi).
  Future<void> recordStudy({required String userId, required int seconds});
}
