import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/comments_repository.dart';
import '../data/repositories/banners_repository.dart';
import '../data/repositories/http_comments_repository.dart';
import '../data/repositories/http_banners_repository.dart';
import '../data/repositories/http_books_repository.dart';
import '../data/repositories/http_lesson_slides_repository.dart';
import '../data/repositories/http_lesson_assets_repository.dart';
import '../data/repositories/http_notifications_repository.dart';
import '../data/repositories/http_purchases_repository.dart';
import '../data/repositories/http_ranking_repository.dart';
import '../data/repositories/http_slides_repository.dart';
import '../data/repositories/http_test_attempt_repository.dart';
import '../data/repositories/books_repository.dart';
import '../data/repositories/catalog_course_repository.dart';
import '../data/repositories/http_quiz_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/purchases_repository.dart';
import '../data/repositories/quiz_repository.dart';
import '../data/repositories/ranking_repository.dart';
import '../data/repositories/lesson_assets_repository.dart';
import '../data/repositories/lesson_slides_repository.dart';
import '../data/repositories/slides_repository.dart';
import '../data/repositories/test_attempt_repository.dart';
import '../services/activation_service.dart';
import '../services/auth_service.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CatalogCourseRepository();
});

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return HttpQuizRepository();
});

final activationServiceProvider = Provider<ActivationService>((ref) {
  return ActivationService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpNotificationsRepository(
    baseUrl: apiBaseUrl,
  );
});

final bannersRepositoryProvider = Provider<BannersRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpBannersRepository(baseUrl: apiBaseUrl);
});

final testAttemptRepositoryProvider = Provider<TestAttemptRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpTestAttemptRepository(baseUrl: apiBaseUrl);
});

final slidesRepositoryProvider = Provider<SlidesRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpSlidesRepository(
    baseUrl: apiBaseUrl,
  );
});

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpCommentsRepository(
    baseUrl: apiBaseUrl,
  );
});

final lessonSlidesRepositoryProvider = Provider<LessonSlidesRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpLessonSlidesRepository(
    baseUrl: apiBaseUrl,
  );
});

final lessonAssetsRepositoryProvider = Provider<LessonAssetsRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpLessonAssetsRepository(
    baseUrl: apiBaseUrl,
  );
});

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpBooksRepository(
    baseUrl: apiBaseUrl,
  );
});

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpPurchasesRepository(
    baseUrl: apiBaseUrl,
  );
});

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  final apiBaseUrl = getApiBaseUrl();
  return HttpRankingRepository(baseUrl: apiBaseUrl);
});

