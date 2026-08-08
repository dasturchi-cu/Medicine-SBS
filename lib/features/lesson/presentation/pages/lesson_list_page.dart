import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../course/presentation/widgets/purchase_modal.dart';
import '../../../../widgets/lesson_item.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final String courseId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final section = repo.getSectionById(courseId, sectionId);
    final isDoctorCourse = courseId == 'course_private_neuro';
    final purchaseState = ref.watch(purchaseControllerProvider);
    final purchased = purchaseState.isPurchased(courseId);
    final basePurchased = purchaseState.isBasePurchased(courseId, sectionId);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('lessons')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(context.tr('section_not_found'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('lessons')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: section.lessons.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final l = section.lessons[i];
          final locked = isDoctorCourse ? !(purchased || basePurchased) : (!purchased && i > 0);

          return LessonItem(
            animationDelayMs: (i % 10) * 45,
            index: i + 1,
            title: l.titleUz,
            duration: l.durationUz,
            locked: locked,
            onTap: () async {
              if (locked) {
                final course = repo.getCourseById(courseId);
                if (course == null) return;
                await showPurchaseModal(
                  context: context,
                  courseName: isDoctorCourse
                      ? '${course.titleUz} - ${section.titleUz}'
                      : course.titleUz,
                  description: isDoctorCourse
                      ? 'Ushbu baza uchun alohida to‘lov qilinadi'
                      : course.descriptionUz,
                  price: course.priceUz,
                  courseId: isDoctorCourse
                      ? basePurchaseKey(course.id, section.id)
                      : course.id,
                );
                return;
              }

              ref.read(selectedCourseIdProvider.notifier).state = courseId;
              ref
                  .read(progressControllerProvider.notifier)
                  .openedLesson(courseId: courseId, lessonId: l.id);
              context.push('${AppRoutes.lesson}?id=${l.id}');
            },
          );
        },
      ),
    );
  }
}
