import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/course/presentation/pages/course_detail_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/books_page.dart';
import '../../features/home/presentation/pages/book_reader_page.dart';
import '../../features/home/presentation/pages/my_courses_page.dart';
import '../../features/home/presentation/pages/notifications_page.dart';
import '../../features/home/presentation/pages/profile_page.dart';
import '../../features/home/presentation/pages/ranking_page.dart';
import '../../features/lesson/presentation/pages/lesson_list_page.dart';
import '../../features/lesson/presentation/pages/lesson_view_page.dart';
import '../../features/lesson/presentation/pages/asset_view_page.dart';
import '../../features/pomodoro/presentation/pages/pomodoro_screen.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/result_page.dart';
import '../../widgets/app_bottom_nav.dart';
import '../router/app_routes.dart';
import '../state/auth_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      if (auth.isBlocked && state.uri.path != AppRoutes.login) {
        return AppRoutes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ShellScaffold(location: state.uri.toString(), child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.myCourses,
            builder: (context, state) => const MyCoursesPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: AppRoutes.ranking,
            builder: (context, state) => const RankingPage(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: AppRoutes.books,
            builder: (context, state) => const BooksPage(),
          ),
          GoRoute(
            path: AppRoutes.bookReader,
            builder: (context, state) {
              final bookId = state.uri.queryParameters['id'] ?? '';
              return BookReaderPage(bookId: bookId);
            },
          ),
          GoRoute(
            path: AppRoutes.courseDetail,
            builder: (context, state) {
              final courseId = state.uri.queryParameters['id'] ?? '';
              return CourseDetailPage(courseId: courseId);
            },
          ),
          GoRoute(
            path: AppRoutes.lessonList,
            builder: (context, state) {
              final courseId = state.uri.queryParameters['courseId'] ?? '';
              final sectionId = state.uri.queryParameters['sectionId'] ?? '';
              return LessonListPage(courseId: courseId, sectionId: sectionId);
            },
          ),
          GoRoute(
            path: AppRoutes.lesson,
            builder: (context, state) {
              final lessonId = state.uri.queryParameters['id'] ?? '';
              return LessonViewPage(lessonId: lessonId);
            },
          ),
          GoRoute(
            path: AppRoutes.lessonAsset,
            builder: (context, state) {
              final lessonId = state.uri.queryParameters['lessonId'] ?? '';
              final assetId = state.uri.queryParameters['assetId'] ?? '';
              return AssetViewPage(lessonId: lessonId, assetId: assetId);
            },
          ),
          GoRoute(
            path: AppRoutes.quiz,
            builder: (context, state) {
              final quizId = state.uri.queryParameters['id'] ?? '';
              return QuizPage(quizId: quizId);
            },
          ),
          GoRoute(
            path: AppRoutes.result,
            builder: (context, state) {
              final score =
                  int.tryParse(state.uri.queryParameters['score'] ?? '') ?? 0;
              final total =
                  int.tryParse(state.uri.queryParameters['total'] ?? '') ?? 0;
              final quizId = state.uri.queryParameters['quizId'] ?? 'quiz_1';
              final correct =
                  int.tryParse(state.uri.queryParameters['correct'] ?? '') ?? 0;
              final totalQuestions = int.tryParse(
                    state.uri.queryParameters['totalQuestions'] ?? '',
                  ) ??
                  0;
              final durationMin = double.tryParse(
                    state.uri.queryParameters['durationMin'] ?? '',
                  ) ??
                  0;
              return ResultPage(
                score: score,
                total: total,
                quizId: quizId,
                correctCount: correct,
                totalQuestions: totalQuestions,
                durationMinutes: durationMin,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.pomodoro,
            builder: (context, state) => const PomodoroScreen(),
          ),
        ],
      ),
    ],
  );
});

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int _indexForLocation() {
    if (location.startsWith(AppRoutes.myCourses)) return 1;
    if (location.startsWith(AppRoutes.pomodoro)) return 2;
    if (location.startsWith(AppRoutes.ranking)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    // For detail pages keep Home tab selected
    return 0;
  }

  void _goTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        return;
      case 1:
        context.go(AppRoutes.myCourses);
        return;
      case 2:
        context.go(AppRoutes.pomodoro);
        return;
      case 3:
        context.go(AppRoutes.ranking);
        return;
      case 4:
        context.go(AppRoutes.profile);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexForLocation();

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
        currentIndex: idx,
        onTap: (i) => _goTab(context, i),
      ),
    );
  }
}
