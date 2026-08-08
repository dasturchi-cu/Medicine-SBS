class RankingItemModel {
  const RankingItemModel({
    required this.userId,
    required this.fullName,
    required this.totalScore,
    required this.quizMinutes,
    required this.rank,
  });

  final String userId;
  final String fullName;
  final double totalScore;
  final double quizMinutes;
  final int rank;

  factory RankingItemModel.fromJson(Map<String, dynamic> json) {
    return RankingItemModel(
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Foydalanuvchi').toString(),
      totalScore: double.tryParse((json['total_score'] ?? '0').toString()) ?? 0,
      quizMinutes: double.tryParse((json['quiz_minutes'] ?? '0').toString()) ?? 0,
      rank: int.tryParse((json['rank'] ?? '0').toString()) ?? 0,
    );
  }
}
