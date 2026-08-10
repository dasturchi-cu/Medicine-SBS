import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/models/course_models.dart';
import '../../../../core/services/catalog_service.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/banners_state.dart';
import '../../../../core/state/books_state.dart';
import '../../../../core/state/course_stats_state.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/state/slides_state.dart';
import '../../../../core/state/notifications_state.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/category_chip.dart';
import '../../../../widgets/course_card.dart';
import '../../../../widgets/course_stats_comments_sheet.dart';
import '../../../course/presentation/widgets/purchase_modal.dart';
import '../providers/home_providers.dart';
import 'books_page.dart' show showLockedBookSheet;

/// Yuqori ko'k slayd uchun `home_slides.course_id`; bo'sh bo'lsa sarlavha bo'yicha bitta mos kurs qidiriladi.
String? _resolveSlideCourseId(String title, String apiCourseId, List<Course> courses) {
  final cid = apiCourseId.trim();
  if (cid.isNotEmpty) return cid;
  final needle = title.trim().toLowerCase();
  if (needle.isEmpty) return null;
  final hits = courses.where((c) => c.titleUz.trim().toLowerCase() == needle).toList();
  if (hits.length == 1) return hits.single.id;
  return null;
}

void _openSlideCourse(
  BuildContext context,
  WidgetRef ref, {
  required String slideTitle,
  required String slideCourseIdRaw,
  required List<Course> courses,
}) {
  final resolved = _resolveSlideCourseId(slideTitle, slideCourseIdRaw, courses);
  if (resolved == null || resolved.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bu slayd uchun kurs ulanmagan. Admin panel → «Bosh sahifa slaydi» bo\'limida «Boshlash» uchun kursni tanlang.',
        ),
      ),
    );
    return;
  }
  ref.read(selectedCourseIdProvider.notifier).state = resolved;
  ref.read(progressControllerProvider.notifier).enroll(resolved);
  context.push('${AppRoutes.courseDetail}?id=$resolved');
}

/// Yuqori slayd fon rasmi (URL yoki admin paneldagi `data:image` Base64).
class _HomeSlideBackdrop extends StatelessWidget {
  const _HomeSlideBackdrop({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final u = imageUrl.trim();
    if (u.isEmpty) {
      return const ColoredBox(color: AppColors.primary);
    }
    if (u.startsWith('data:image')) {
      const marker = ';base64,';
      final idx = u.indexOf(marker);
      if (idx >= 0) {
        try {
          final b64 = u.substring(idx + marker.length).trim();
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.primary),
          );
        } catch (_) {
          return const ColoredBox(color: AppColors.primary);
        }
      }
    }
    return Image.network(
      u,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: AppColors.primary),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(color: AppColors.primary);
      },
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  Timer? _loadingTimer;
  bool _loading = true;
  int _slideCount = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_refreshCatalog);
    _loadingTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _loading = false);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      final index = next % (_slideCount <= 0 ? 1 : _slideCount);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _loadingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCatalog());
    }
  }

  Future<void> _refreshCatalog() async {
    await Future.wait<void>([
      CatalogService.bootstrap(),
      _syncRemoteVideoProgress(),
    ]);
    if (!mounted) return;
    ref.invalidate(slidesFeedProvider);
    ref.invalidate(bannersFeedProvider);
    setState(() {});
  }

  Future<void> _syncRemoteVideoProgress() async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/courses/progress?user_id=$userId'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List) return;
      final completedByCourse = <String, Set<String>>{};
      final watchedByCourse = <String, Set<String>>{};
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final courseId = (raw['course_id'] ?? '').toString();
        final lessonId = (raw['lesson_id'] ?? '').toString();
        if (courseId.isEmpty || lessonId.isEmpty) continue;
        final watchedSec = int.tryParse((raw['watched_sec'] ?? '0').toString()) ?? 0;
        if (watchedSec > 0) {
          watchedByCourse.putIfAbsent(courseId, () => <String>{}).add(lessonId);
        }
        final completed = raw['completed'] == true;
        if (completed) {
          completedByCourse.putIfAbsent(courseId, () => <String>{}).add(lessonId);
        }
      }
      ref
          .read(progressControllerProvider.notifier)
          .mergeWatchedFromServer(watchedByCourse);
      ref
          .read(progressControllerProvider.notifier)
          .mergeCompletedFromServer(completedByCourse);
    } catch (_) {
      // Ignore network errors; local state still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = ref.watch(selectedCategoryIdProvider);
    final query = ref.watch(homeSearchQueryProvider).trim().toLowerCase();
    final repo = ref.watch(courseRepositoryProvider);
    final allCourses = repo.getCourses();
    final slidesAsync = ref.watch(slidesFeedProvider);
    final bannersAsync = ref.watch(bannersFeedProvider);
    final booksAsync = ref.watch(booksFeedProvider);
    final remoteSlides = slidesAsync.valueOrNull ?? const [];
    // Faqat serverdagi home_slides — admin bo'sh qoldirsa kurslardan «soxta» slayd chiqmasin.
    final slideItems = remoteSlides
        .map(
          (item) => (
            title: item.title,
            courseId: item.courseId ?? '',
            buttonText: item.buttonText,
            imageUrl: item.imageUrl,
          ),
        )
        .toList(growable: false);
    _slideCount = slideItems.length;
    final courses = allCourses.where((c) {
      final matchesCategory = switch (selectedCat) {
        'cat_books' => false,
        'cat_nevralogiya' => true,
        'cat_online' => false,
        _ => false,
      };
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return c.titleUz.toLowerCase().contains(query) ||
          c.authorUz.toLowerCase().contains(query);
    }).toList();
    String? catalogLoadError;
    try {
      catalogLoadError = CatalogService.lastLoadError;
    } catch (_) {
      // Hot-reload paytida eski state qolib ketsa build crash bo'lmasin.
      catalogLoadError = null;
    }
    final remoteBanners = bannersAsync.valueOrNull ?? const [];
    final newsItems = remoteBanners
        .map(
          (banner) {
            final linkedCourseId = (banner.courseId ?? '').trim();
            final externalTelegramOnly = linkedCourseId.isEmpty;
            return _NewsItem(
              id: banner.id,
              titleUz: banner.title,
              summaryUz: banner.message.isEmpty
                  ? (externalTelegramOnly
                      ? 'Telegram maxfiy kanalidagi tashqi kurs'
                      : 'Onlayn kurslar uchun reklama')
                  : banner.message,
              feedbackKey: externalTelegramOnly ? banner.id : linkedCourseId,
              platformCourseId: externalTelegramOnly ? null : linkedCourseId,
              telegramContact: banner.telegram.trim().isEmpty
                  ? 'Mr_Xusanboy'
                  : banner.telegram.trim(),
              useFeedbackApi: externalTelegramOnly,
              imageUrl: banner.imageUrl.isEmpty
                  ? 'https://picsum.photos/seed/${banner.id}/600/320'
                  : banner.imageUrl,
              rating: 0,
              commentCount: 0,
              priceText: banner.priceLabel.isEmpty
                  ? "299 000 so'm"
                  : banner.priceLabel,
            );
          },
        )
        .toList(growable: false);
    final progress = ref.watch(progressControllerProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshCatalog,
        child: CustomScrollView(
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          ref.read(homeSearchQueryProvider.notifier).state = v,
                      decoration: InputDecoration(
                        hintText: context.tr('search_hint'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () =>
                                    ref
                                            .read(
                                              homeSearchQueryProvider.notifier,
                                            )
                                            .state =
                                        '',
                                icon: const Icon(Icons.close),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final unread = ref
                                .watch(notificationsFeedProvider)
                                .valueOrNull
                                ?.where((n) => !n.viewed)
                                .length ??
                            0;
                        return IconButton(
                          icon: Badge.count(
                            count: unread,
                            isLabelVisible: unread > 0,
                            child: const Icon(Icons.notifications_none),
                          ),
                          onPressed: () {
                            context.push(AppRoutes.notifications);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (slideItems.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 154,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slideItems.length,
                itemBuilder: (context, index) {
                  final slide = slideItems[index];
                  final courseId = slide.courseId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openSlideCourse(context, ref,
                          slideTitle: slide.title,
                          slideCourseIdRaw: courseId,
                          courses: allCourses),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: AppShadows.soft,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: _HomeSlideBackdrop(imageUrl: slide.imageUrl),
                                ),
                                if (slide.imageUrl.trim().isNotEmpty)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          stops: const [0.0, 0.45, 1.0],
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.90),
                                            AppColors.primary.withValues(alpha: 0.48),
                                            AppColors.primary.withValues(alpha: 0.12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (slide.imageUrl.trim().isEmpty)
                                  Positioned(
                                    right: -24,
                                    top: 10,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.s16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        slide.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.s12),
                                      SizedBox(
                                        height: 36,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                AppRadius.button,
                                              ),
                                            ),
                                            backgroundColor: Colors.white,
                                            foregroundColor: AppColors.primary,
                                          ),
                                          onPressed: () => _openSlideCourse(
                                            context,
                                            ref,
                                            slideTitle: slide.title,
                                            slideCourseIdRaw: courseId,
                                            courses: allCourses,
                                          ),
                                          child: Text(
                                            slide.buttonText,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (slideItems.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: slideItems.length,
                    effect: WormEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      activeDotColor: const Color(0xFF1E6BB8),
                      dotColor: Colors.black.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'Kategoriyalar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: CategoryChip(
                      label: 'Kurslar',
                      selected: selectedCat == 'cat_nevralogiya',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_nevralogiya',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: 'Kitoblar',
                      selected: selectedCat == 'cat_books',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_books',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: 'Onlayn kurslar',
                      selected: selectedCat == 'cat_online',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_online',
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: catalogLoadError != null && allCourses.isEmpty
                  ? Material(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Kurslar yuklanmadi: $catalogLoadError\n'
                          'Internet va API_BASE_URL ni tekshiring. Pastga torting (yangilash).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (selectedCat == 'cat_online') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Kanal yangiliklari',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 306,
                child: newsItems.isEmpty
                    ? Center(
                        child: Text(
                          'Hozircha reklama joylanmagan',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        itemCount: newsItems.length,
                        separatorBuilder: (_, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final news = newsItems[index];
                          return _NewsCard(
                            item: news,
                            onBuyTap: () async {
                              await showPurchaseModal(
                                context: context,
                                courseName: news.titleUz,
                                description: news.summaryUz,
                                price: news.priceText,
                                courseId: news.platformCourseId,
                                telegramRecipient: news.telegramContact,
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
          if (selectedCat == 'cat_nevralogiya') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.tr('home_section_sections'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final c = courses[index];
                final cardStatsAsync = ref.watch(courseCardStatsProvider(c.id));
                final cardStats = cardStatsAsync.valueOrNull;
                final p = progress.byCourseId[c.id];
                final totalLessons = repo.getFlattenLessons(c.id).length;
                final watched = p?.watchedLessonIds.length ?? 0;
                final progressValue = totalLessons == 0
                    ? 0.0
                    : (watched / totalLessons).toDouble().clamp(0.0, 1.0);

                final buttonText = (p?.enrolled ?? false) || progressValue > 0
                    ? 'Davom et'
                    : context.tr('btn_start');
                const buttonColor = AppColors.primary;

                if (_loading) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    child: const SizedBox(height: 92),
                  );
                }

                return CourseCard(
                  animationDelayMs: (index % 8) * 55,
                  videoCountOnly: true,
                  visualKind: c.titleUz == 'Xususiy Nevrologiya (Bakalavr uchun)'
                      ? 'xususiy_bachelor'
                      : c.titleUz == 'Umumiy Nevrologiya (Bakalavr uchun)'
                      ? 'umumiy_bachelor'
                      : c.titleUz == 'Xususiy nevrologiya (shifokorlar uchun)'
                      ? 'xususiy_doctors'
                      : c.titleUz == 'EEG'
                      ? 'eeg_img'
                      : c.titleUz == 'Epileptologiya'
                      ? 'epileptologiya_img'
                      : c.titleUz == 'ENMG'
                      ? 'enmg_img'
                      : 'brain',
                  title: c.titleUz,
                  author: c.authorUz,
                  imageUrl: c.imageUrl,
                  progress: progressValue,
                  ratingText: (cardStats?.ratingAvg ?? c.rating).toStringAsFixed(1),
                  commentCountText: '${cardStats?.commentsCount ?? 0} ta sharh',
                  videoCountText: '$totalLessons ta video',
                  buttonText: buttonText,
                  buttonColor: buttonColor,
                  onMessagePressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: false,
                      builder: (_) => CourseStatsCommentsSheet(
                        courseId: c.id,
                        courseTitleUz: c.titleUz,
                      ),
                    );
                  },
                  onPressed: () {
                    ref.read(selectedCourseIdProvider.notifier).state = c.id;
                    ref.read(progressControllerProvider.notifier).enroll(c.id);

                    if (buttonText == 'Davom et') {
                      final firstSection = c.sections.isNotEmpty
                          ? c.sections.first
                          : null;
                      if (firstSection != null) {
                        context.push(
                          '${AppRoutes.lessonList}?courseId=${c.id}&sectionId=${firstSection.id}',
                        );
                        return;
                      }
                    }

                    context.push('${AppRoutes.courseDetail}?id=${c.id}');
                  },
                );
              },
            ),
          ],
          if (selectedCat == 'cat_books')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kitoblar kutubxonasi',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Jami: ${(booksAsync.valueOrNull ?? const []).length} ta kitob',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        if ((booksAsync.valueOrNull ?? const []).isNotEmpty) ...[
                          ...((booksAsync.valueOrNull ?? const []).take(4).map(
                                (book) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                                    ),
                                    leading: Icon(
                                      book.isLocked ? Icons.lock_outline : Icons.menu_book_outlined,
                                      color: book.isLocked ? AppColors.primary : null,
                                    ),
                                    title: Text(
                                      book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      book.isLocked
                                          ? "${_formatBookPrice(book.priceUzs)} so'm · Qulf 🔒"
                                          : (book.author.isEmpty ? 'Muallif ko‘rsatilmagan' : book.author),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: book.isLocked
                                        ? const Icon(Icons.lock_outline, size: 18, color: AppColors.primary)
                                        : null,
                                    onTap: () {
                                      if (book.isLocked) {
                                        showLockedBookSheet(context, ref, book);
                                      } else {
                                        context.push('${AppRoutes.bookReader}?id=${book.id}');
                                      }
                                    },
                                  ),
                                ),
                              )),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              context.tr('books_empty'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.push(AppRoutes.books),
                            child: Text((booksAsync.valueOrNull ?? const []).isEmpty ? "Kitob qo'shilgach shu yerda chiqadi" : "Barcha kitoblar"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.onBuyTap,
  });

  final _NewsItem item;
  final VoidCallback onBuyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 312,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  final dataImage = _decodeDataImage(item.imageUrl);
                  if (dataImage != null) {
                    return Image.memory(dataImage, fit: BoxFit.cover);
                  }
                  return Container(
                    color: const Color(0xFFE7EEF9),
                    child: const Center(
                      child: Icon(Icons.image_outlined, color: AppColors.primary),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titleUz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summaryUz,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onBuyTap,
                      child: const Text('Sotib olish'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsItem {
  const _NewsItem({
    required this.id,
    required this.titleUz,
    required this.summaryUz,
    required this.feedbackKey,
    required this.platformCourseId,
    required this.telegramContact,
    required this.useFeedbackApi,
    required this.imageUrl,
    required this.rating,
    required this.commentCount,
    required this.priceText,
  });

  final String id;
  final String titleUz;
  final String summaryUz;
  /// Sharhlar/statistikada kalit (platforma kursi ID yoki tashqi reklama uchun banner ID).
  final String feedbackKey;
  /// `null` bo‘lsa bu karta ilova ichidagi kursga bog‘lanmaydi (faqat Telegram).
  final String? platformCourseId;
  final String telegramContact;
  final bool useFeedbackApi;
  final String imageUrl;
  final double rating;
  final int commentCount;
  final String priceText;
}

String _formatBookPrice(double v) {
  final s = v.toStringAsFixed(0);
  return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
}

Uint8List? _decodeDataImage(String value) {
  if (!value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex < 0 || commaIndex >= value.length - 1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
