import '../models/ranking_models.dart';

abstract class RankingRepository {
  /// [period]: daily | weekly | monthly | yearly | overall
  Future<List<RankingItemModel>> fetchRanking({
    int limit = 50,
    String period = 'overall',
  });
}
