import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/progress_controller.dart';

class ResultPage extends ConsumerStatefulWidget {
  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.quizId,
    required this.correctCount,
    required this.totalQuestions,
    required this.durationMinutes,
  });

  final int score;
  final int total;
  final String quizId;
  final int correctCount;
  final int totalQuestions;
  final double durationMinutes;

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  bool _sentAttempt = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (_sentAttempt) return;
      final userId = ref.read(authControllerProvider).userId;
      if (userId == null || userId.isEmpty) return;
      await ref
          .read(testAttemptRepositoryProvider)
          .submitAttempt(
            quizId: widget.quizId,
            userId: userId,
            scorePercent: widget.score.toDouble(),
            correctCount: widget.correctCount,
            totalQuestions: widget.totalQuestions,
            durationMinutes: widget.durationMinutes,
          );
      _sentAttempt = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.score >= 50;

    return Scaffold(
      appBar: AppBar(title: const Text('Natija')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Natija',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      'Yakuniy ball',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.score}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: passed
                            ? const Color(0xFFE7F8EF)
                            : const Color(0xFFFFEEE9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        passed ? 'O‘tdingiz' : 'O‘tmadingiz',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: passed ? const Color(0xFF1B7B3A) : const Color(0xFFB64023),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Testni qayta ishlash yoki keyingi darsga o‘tish mumkin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        context.pushReplacement('${AppRoutes.quiz}?id=${widget.quizId}');
                      },
                      child: const Text(
                        'Qayta',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6BB8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        final courseId = ref.read(selectedCourseIdProvider);
                        if (courseId == null) {
                          context.go(AppRoutes.home);
                          return;
                        }
                        final repo = ref.read(courseRepositoryProvider);
                        final progress = ref.read(progressControllerProvider);
                        final currentLesson = progress.byCourseId[courseId]?.lastLessonId ??
                            repo.getFirstUnlockedLesson(courseId)?.id;
                        if (currentLesson == null) {
                          context.go(AppRoutes.home);
                          return;
                        }
                        final next = repo.getNextLessonId(courseId, currentLesson);
                        final target = next ?? currentLesson;
                        context.push('${AppRoutes.lesson}?id=$target');
                      },
                      child: const Text(
                        'Keyingi dars',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

