import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/lesson_assets_state.dart';
import '../../../../core/state/lesson_slides_state.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/video_player_box.dart';

bool _renderedSlideHasVisual(_RenderedSlide slide) {
  if (slide.imageUrl.trim().isNotEmpty) return true;
  return (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideIsPdfAsset(_RenderedSlide slide) {
  return (slide.assetType ?? '').toLowerCase() == 'pdf' &&
      (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideIsPptAsset(_RenderedSlide slide) {
  return (slide.assetType ?? '').toLowerCase() == 'ppt' &&
      (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideHasCoverImage(_RenderedSlide slide) {
  return slide.imageUrl.trim().isNotEmpty && !_slideIsPdfAsset(slide);
}

/// `lesson_assets` bo‘lsa ham, mirror qilingan `lesson_slides` ko‘proq bo‘lishi mumkin —
/// faqat assetlarni tanlash jami slayd/rasm sonini pasaytirardi.
List<_RenderedSlide> _mergeLessonSlidesAndAssets({
  required List<_RenderedSlide> assetSlides,
  required List<_RenderedSlide> renderedSlides,
  required bool hasLessonAssets,
  required bool hasRemoteLessonSlides,
}) {
  if (!hasLessonAssets) return renderedSlides;
  if (!hasRemoteLessonSlides) return assetSlides;

  final visualsFromSlides =
      renderedSlides.where(_renderedSlideHasVisual).length;
  final visualsFromAssets =
      assetSlides.where(_renderedSlideHasVisual).length;
  final preferRendered =
      renderedSlides.length > assetSlides.length ||
          visualsFromSlides > visualsFromAssets;

  return preferRendered ? renderedSlides : assetSlides;
}

class LessonViewPage extends ConsumerStatefulWidget {
  const LessonViewPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonViewPage> createState() => _LessonViewPageState();
}

class _LessonViewPageState extends ConsumerState<LessonViewPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late PageController _slidesController;
  int _lastSyncedWatchSec = 0;
  bool _syncingWatch = false;
  int _initialWatchedSec = 0;
  bool _loadingInitialProgress = false;
  bool _progressChecked = false;
  String? _loadedProgressKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _slidesController = PageController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LessonViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      _slidesController.dispose();
      _slidesController = PageController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepositoryProvider);
    final lesson = repo.getLessonById(widget.lessonId);
    final lessonSlidesAsync = ref.watch(lessonSlidesProvider(widget.lessonId));
    final courseId = repo.getCourseIdForLesson(widget.lessonId);
    final orientation = MediaQuery.orientationOf(context);
    final size = MediaQuery.sizeOf(context);
    final mediaHeight = orientation == Orientation.landscape
        ? size.height * 0.78
        : size.height * 0.46;

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dars'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Dars topilmadi')),
      );
    }

    final remoteSlides = lessonSlidesAsync.valueOrNull ?? const [];
    final lessonAssets =
        ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ??
        const [];
    final sortedAssets = [...lessonAssets]
      ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
    final assetSlides = sortedAssets
        .map(
          (asset) => _RenderedSlide(
            title: asset.title,
            body: asset.description,
            imageUrl: asset.previewImageUrl,
            assetType: asset.fileType,
            assetFileUrl: asset.fileUrl,
          ),
        )
        .toList(growable: false);
    final renderedSlides = remoteSlides.isNotEmpty
        ? remoteSlides
              .map(
                (item) => _RenderedSlide(
                  title: item.title,
                  body: item.body,
                  imageUrl: item.imageUrl,
                ),
              )
              .toList(growable: false)
        : lesson.slides
              .map(
                (text) => _RenderedSlide(title: text, body: '', imageUrl: ''),
              )
              .toList(growable: false);
    final mergedSlides = _mergeLessonSlidesAndAssets(
      assetSlides: assetSlides,
      renderedSlides: renderedSlides,
      hasLessonAssets: lessonAssets.isNotEmpty,
      hasRemoteLessonSlides: remoteSlides.isNotEmpty,
    );
    final showLessonTextBlock =
        lesson.transcriptUz.trim().isNotEmpty &&
            !mergedSlides.any(_renderedSlideHasVisual);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dars tafsiloti'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _confirmAndLeave,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E6BB8),
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: const Color(0xFF1E6BB8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'Video'),
                Tab(text: 'Taqdimot'),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0) {
                if (courseId != null) {
                  _ensureInitialWatchProgressLoaded(courseId);
                }
                // Progress yuklanmaguncha pleyerni qurmaymiz — aks holda 0 dan
                // boshlab, keyin qayta yaratilib "boshiga qaytardi". Yuklab bo'lgach
                // barqaror key bilan bir marta to'g'ri joydan quramiz.
                final progressReady = courseId == null || _progressChecked;
                if (!progressReady) {
                  return SizedBox(
                    height: mediaHeight,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                return VideoPlayerBox(
                  key: ValueKey('video:${widget.lessonId}'),
                  url: lesson.videoUrl,
                  height: mediaHeight,
                  initialWatchedSec: _initialWatchedSec,
                  onWatchProgress: (watchedSec, completed) {
                    if (!mounted) return;
                    if (courseId == null) return;
                    _syncWatchProgress(
                      courseId: courseId,
                      watchedSec: watchedSec,
                      completed: completed,
                    );
                  },
                );
              }
              return _SlideViewer(
                slides: mergedSlides,
                controller: _slidesController,
                height: mediaHeight,
                lessonId: widget.lessonId,
              );
            },
          ),
          const SizedBox(height: 12),
          if (showLessonTextBlock) ...[
            Text(
              'Dars matni',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  lesson.transcriptUz,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (courseId != null) {
                        ref.read(selectedCourseIdProvider.notifier).state =
                            courseId;
                        ref
                            .read(progressControllerProvider.notifier)
                            .completeLesson(
                              courseId: courseId,
                              lessonId: widget.lessonId,
                            );
                        final course = repo.getCourseById(courseId);
                        String? sectionId;
                        if (course != null) {
                          for (final section in course.sections) {
                            final hasLesson = section.lessons.any(
                              (lessonItem) => lessonItem.id == widget.lessonId,
                            );
                            if (hasLesson) {
                              sectionId = section.id;
                              break;
                            }
                          }
                        }
                        if (sectionId != null && sectionId.isNotEmpty) {
                          context.pushReplacement(
                            '${AppRoutes.lessonList}?courseId=$courseId&sectionId=$sectionId',
                          );
                          return;
                        }
                      }
                      context.pop();
                    },
                    child: const Text(
                      'Darsni yakunlash',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BB8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (courseId != null) {
                        ref.read(selectedCourseIdProvider.notifier).state =
                            courseId;
                        ref
                            .read(progressControllerProvider.notifier)
                            .completeLesson(
                              courseId: courseId,
                              lessonId: widget.lessonId,
                            );
                      }
                      context.push('${AppRoutes.quiz}?id=${widget.lessonId}');
                    },
                    child: const Text(
                      'Testga o‘tish',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _syncWatchProgress({
    required String courseId,
    required int watchedSec,
    required bool completed,
  }) async {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    final shouldSync = completed || watchedSec >= _lastSyncedWatchSec + 20;
    if (!shouldSync) return;
    // Yakunlanishni oldingi sync bloklamasin — aks holda completed=true serverga umuman ketmaydi.
    if (_syncingWatch && !completed) return;
    _syncingWatch = true;
    _lastSyncedWatchSec = watchedSec;
    try {
      debugPrint(
        '[API][courses.view][request] courseId=$courseId lessonId=${widget.lessonId} userId=$userId watchedSec=$watchedSec completed=$completed',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/courses/$courseId/views'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'lesson_id': widget.lessonId,
          'watched_sec': watchedSec,
          'completed': completed,
        }),
      );
      debugPrint('[API][courses.view][response] status=${response.statusCode}');
    } catch (error) {
      debugPrint('[API][courses.view][error] $error');
    } finally {
      _syncingWatch = false;
    }
  }

  Future<void> _confirmAndLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Darsdan chiqish'),
        content: const Text('Rostan ham darsdan chiqasizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Yoq')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ha')),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  Future<void> _ensureInitialWatchProgressLoaded(String courseId) async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    final key = '$userId|$courseId|${widget.lessonId}';
    if (_loadedProgressKey == key || _loadingInitialProgress) return;
    _loadingInitialProgress = true;
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1/courses/progress'
        '?user_id=$userId&course_id=$courseId&lesson_id=${widget.lessonId}',
      );
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List || items.isEmpty) {
        _loadedProgressKey = key;
        return;
      }
      final row = items.first;
      if (row is! Map<String, dynamic>) return;
      final watched = int.tryParse((row['watched_sec'] ?? '0').toString()) ?? 0;
      if (!mounted) return;
      setState(() {
        _initialWatchedSec = watched > 0 ? watched : 0;
        _lastSyncedWatchSec = _initialWatchedSec;
        _loadedProgressKey = key;
      });
    } catch (_) {
      // Silent fail: player still starts from 0 if restore failed.
    } finally {
      _loadingInitialProgress = false;
      _loadedProgressKey = key; // qayta-qayta so'ramaslik uchun
      if (mounted && !_progressChecked) {
        setState(() => _progressChecked = true);
      }
    }
  }
}

/// Qo‘lda surilganda sahifalar tezroq “snap” bo‘lishi uchun qattiq spring.
class _SnappyPageScrollPhysics extends PageScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.42,
        stiffness: 9000,
        ratio: 1.02,
      );
}

class _SlideViewer extends StatefulWidget {
  const _SlideViewer({
    required this.slides,
    required this.controller,
    required this.height,
    required this.lessonId,
  });

  final List<_RenderedSlide> slides;
  final PageController controller;
  final double height;
  final String lessonId;

  @override
  State<_SlideViewer> createState() => _SlideViewerState();
}

class _SlideViewerState extends State<_SlideViewer> {
  int _page = 0;
  PdfViewerController? _pdfDeckController;
  int? _pdfPageNumber;
  int? _pdfPageCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageFromController());
  }

  @override
  void didUpdateWidget(covariant _SlideViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lessonChanged = oldWidget.lessonId != widget.lessonId;
    final countChanged = oldWidget.slides.length != widget.slides.length;
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _page = 0;
    }
    if (lessonChanged || countChanged || controllerChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageFromController());
    }
  }

  void _syncPageFromController() {
    if (!mounted || widget.slides.isEmpty) return;
    final maxIdx = widget.slides.length - 1;
    if (!widget.controller.hasClients) {
      final initial = widget.controller.initialPage.clamp(0, maxIdx);
      if (_page != initial) setState(() => _page = initial);
      return;
    }
    final fromOffset =
        (widget.controller.page ?? widget.controller.initialPage.toDouble())
            .round()
            .clamp(0, maxIdx);
    if (fromOffset != _page) setState(() => _page = fromOffset);
  }

  void _onPageChanged(int index) {
    if (!mounted || widget.slides.isEmpty) return;
    final clamped = index.clamp(0, widget.slides.length - 1);
    if (clamped == _page) return;
    setState(() {
      _page = clamped;
      _pdfDeckController = null;
      _pdfPageNumber = null;
      _pdfPageCount = null;
    });
  }

  void _onPdfControllerReady(int slideIndex, PdfViewerController c) {
    if (!mounted || slideIndex != _page) return;
    setState(() => _pdfDeckController = c);
  }

  void _onPdfControllerDisposed(PdfViewerController c) {
    if (_pdfDeckController != c) return;
    _pdfDeckController = null;
    if (mounted) setState(() {});
  }

  void _onPdfPaginationFromViewer(int slideIndex, int page, int totalPages) {
    if (!mounted || slideIndex != _page || totalPages <= 0) return;
    final safePage = page.clamp(1, totalPages);
    setState(() {
      _pdfPageNumber = safePage;
      _pdfPageCount = totalPages;
    });
  }

  bool _chromePrevEnabled(List<_RenderedSlide> slides) {
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      if (pn > 1) return true;
      return slides.length > 1 && _page > 0;
    }
    return slides.length > 1 && _page > 0;
  }

  bool _chromeNextEnabled(List<_RenderedSlide> slides) {
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      final tc = _pdfPageCount!;
      if (pn < tc) return true;
      return slides.length > 1 && _page < slides.length - 1;
    }
    return slides.length > 1 && _page < slides.length - 1;
  }

  void _chromePrev(PageController carousel) {
    final slides = widget.slides;
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      if (pn > 1) {
        _pdfDeckController!.previousPage();
        return;
      }
    }
    if (slides.length > 1 && _page > 0) {
      carousel.previousPage(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
      );
    }
  }

  void _chromeNext(PageController carousel) {
    final slides = widget.slides;
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      final tc = _pdfPageCount!;
      if (pn < tc) {
        _pdfDeckController!.nextPage();
        return;
      }
    }
    if (slides.length > 1 && _page < slides.length - 1) {
      carousel.nextPage(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openFullscreen() async {
    if (widget.slides.isEmpty) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullscreenSlidePage(slides: widget.slides, initialIndex: _page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final controller = widget.controller;
    if (slides.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E6BB8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Slaydlar hali qo\'shilmagan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    final deckSlide = slides[_page];
    final pdfPaginationKnown = _slideIsPdfAsset(deckSlide) &&
        (_pdfPageCount != null && _pdfPageCount! > 0);
    final chromeNumerator =
        pdfPaginationKnown ? (_pdfPageNumber ?? 1) : (_page + 1);
    final chromeDenominator =
        pdfPaginationKnown ? _pdfPageCount! : slides.length;
    final chromeSubtitle = pdfPaginationKnown
        ? '$chromeNumerator-sahifa · jami $chromeDenominator ta'
        : '${_page + 1}-chi rasm · jami ${slides.length} ta';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const _SnappyPageScrollPhysics().applyTo(
                ClampingScrollPhysics(),
              ),
              itemCount: slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                    final slide = slides[index];
                    final isPdf = _slideIsPdfAsset(slide);
                    final isPpt = _slideIsPptAsset(slide);
                    final cover = _slideHasCoverImage(slide);

                    late final Widget layer;
                    if (cover) {
                      layer = ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _SlideImage(
                          imageUrl: slide.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholderHeight: widget.height,
                        ),
                      );
                    } else if (isPdf) {
                      layer = Padding(
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _InlinePdfPreview(
                            key: ValueKey(slide.assetFileUrl),
                            url: slide.assetFileUrl!,
                            slideIndex: index,
                            isActiveDeckSlide: index == _page,
                            onControllerReady: _onPdfControllerReady,
                            onControllerDisposed: _onPdfControllerDisposed,
                            onPaginationFromPdf: _onPdfPaginationFromViewer,
                          ),
                        ),
                      );
                    } else if (isPpt) {
                      layer = Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final uri = Uri.tryParse(slide.assetFileUrl!);
                            if (uri == null) return;
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('PPT ni ochish'),
                        ),
                      );
                    } else {
                      layer = Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (slide.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF1E6BB8)),
                        Positioned.fill(child: layer),
                      ],
                    );
                  },
                ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                ),
                onPressed: _openFullscreen,
                icon: const Icon(Icons.fullscreen),
                tooltip: 'Katta ko‘rish',
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.94),
                            foregroundColor: const Color(0xFF1E6BB8),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                const Color(0xFF1E6BB8).withValues(
                              alpha: 0.35,
                            ),
                          ),
                          onPressed: _chromePrevEnabled(slides)
                              ? () => _chromePrev(controller)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (slides.length > 1)
                                SmoothPageIndicator(
                                  controller: controller,
                                  count: slides.length,
                                  effect: WormEffect(
                                    dotWidth: 7,
                                    dotHeight: 7,
                                    spacing: 6,
                                    activeDotColor: const Color(0xFF1E6BB8),
                                    dotColor: const Color(0xFF1E6BB8)
                                        .withValues(alpha: 0.28),
                                  ),
                                ),
                              if (slides.length > 1) const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.14,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$chromeNumerator / $chromeDenominator',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF1E6BB8),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        height: 1.1,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      chromeSubtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xFF1E6BB8)
                                            .withValues(alpha: 0.72),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.94),
                            foregroundColor: const Color(0xFF1E6BB8),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                const Color(0xFF1E6BB8).withValues(
                              alpha: 0.35,
                            ),
                          ),
                          onPressed: _chromeNextEnabled(slides)
                              ? () => _chromeNext(controller)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenSlidePage extends StatefulWidget {
  const _FullscreenSlidePage({
    required this.slides,
    required this.initialIndex,
  });

  final List<_RenderedSlide> slides;
  final int initialIndex;

  @override
  State<_FullscreenSlidePage> createState() => _FullscreenSlidePageState();
}

class _FullscreenSlidePageState extends State<_FullscreenSlidePage> {
  late final PageController _controller;
  late int _index;
  int? _fullscreenPdfPage;
  int? _fullscreenPdfTotal;

  @override
  void initState() {
    super.initState();
    if (widget.slides.isEmpty) {
      _index = 0;
      _controller = PageController(initialPage: 0);
      return;
    }
    _index = widget.initialIndex.clamp(0, widget.slides.length - 1);
    _controller = PageController(initialPage: _index);
    _lockLandscape();
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _unlockOrientation();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fsSlides = widget.slides;
    final fsDeck = fsSlides.isEmpty
        ? null
        : fsSlides[_index.clamp(0, fsSlides.length - 1)];
    final fsPdfKnown = fsDeck != null &&
        _slideIsPdfAsset(fsDeck) &&
        (_fullscreenPdfTotal != null && _fullscreenPdfTotal! > 0);
    final fsNum = fsPdfKnown ? (_fullscreenPdfPage ?? 1) : (_index + 1);
    final fsDenom =
        fsPdfKnown ? _fullscreenPdfTotal! : fsSlides.length.clamp(1, 1 << 30);
    final fsSubtitle = fsPdfKnown
        ? '$fsNum-sahifa · jami $fsDenom ta'
        : '${_index + 1}-chi rasm · jami ${fsSlides.length} ta';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const _SnappyPageScrollPhysics().applyTo(
              ClampingScrollPhysics(),
            ),
            itemCount: widget.slides.length,
            onPageChanged: (v) => setState(() {
              _index = v;
              _fullscreenPdfPage = null;
              _fullscreenPdfTotal = null;
            }),
            itemBuilder: (context, i) {
              final slide = widget.slides[i];
              final isPdf = _slideIsPdfAsset(slide);
              final isPpt = _slideIsPptAsset(slide);
              final cover = _slideHasCoverImage(slide);

              late final Widget body;
              if (cover) {
                body = _SlideImage(
                  imageUrl: slide.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholderHeight: MediaQuery.sizeOf(context).shortestSide,
                );
              } else if (isPdf) {
                body = Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _InlinePdfPreview(
                      key: ValueKey(slide.assetFileUrl),
                      url: slide.assetFileUrl!,
                      slideIndex: i,
                      isActiveDeckSlide: i == _index,
                      onPaginationFromPdf: (slideIndex, page, totalPages) {
                        if (!mounted ||
                            slideIndex != _index ||
                            totalPages <= 0) {
                          return;
                        }
                        setState(() {
                          _fullscreenPdfPage = page.clamp(1, totalPages);
                          _fullscreenPdfTotal = totalPages;
                        });
                      },
                    ),
                  ),
                );
              } else if (isPpt) {
                body = Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    onPressed: () async {
                      final uri = Uri.tryParse(slide.assetFileUrl!);
                      if (uri == null) return;
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('PPT ni ochish'),
                  ),
                );
              } else {
                body = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (slide.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF1E6BB8)),
                    Positioned.fill(child: body),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_fullscreen),
              tooltip: 'Chiqish',
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.fullscreen_exit),
              tooltip: 'Kichraytirish',
            ),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fsSlides.length > 1)
                    AnimatedSmoothIndicator(
                      activeIndex: _index,
                      count: fsSlides.length,
                      effect: WormEffect(
                        dotWidth: 8,
                        dotHeight: 8,
                        spacing: 7,
                        activeDotColor: const Color(0xFF1E6BB8),
                        dotColor:
                            const Color(0xFF1E6BB8).withValues(alpha: 0.28),
                      ),
                    ),
                  if (fsSlides.length > 1) const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$fsNum / $fsDenom',
                            style: const TextStyle(
                              color: Color(0xFF1E6BB8),
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fsSubtitle,
                            style: TextStyle(
                              color: const Color(0xFF1E6BB8).withValues(
                                alpha: 0.72,
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderedSlide {
  const _RenderedSlide({
    required this.title,
    required this.body,
    required this.imageUrl,
    this.assetType,
    this.assetFileUrl,
  });

  final String title;
  final String body;
  final String imageUrl;
  final String? assetType;
  final String? assetFileUrl;
}

class _InlinePdfPreview extends StatefulWidget {
  const _InlinePdfPreview({
    super.key,
    required this.url,
    this.slideIndex = 0,
    this.isActiveDeckSlide = true,
    this.onControllerReady,
    this.onControllerDisposed,
    this.onPaginationFromPdf,
  });

  final String url;
  final int slideIndex;
  final bool isActiveDeckSlide;
  final void Function(int slideIndex, PdfViewerController controller)?
      onControllerReady;
  final void Function(PdfViewerController controller)? onControllerDisposed;
  final void Function(int slideIndex, int page, int totalPages)?
      onPaginationFromPdf;

  @override
  State<_InlinePdfPreview> createState() => _InlinePdfPreviewState();
}

class _InlinePdfPreviewState extends State<_InlinePdfPreview> {
  late final Future<Uint8List> _bytesFuture;
  late final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes(widget.url);
    if (widget.isActiveDeckSlide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onControllerReady?.call(widget.slideIndex, _pdfViewerController);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _InlinePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActiveDeckSlide && widget.isActiveDeckSlide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onControllerReady?.call(widget.slideIndex, _pdfViewerController);
        _syncPaginationFromController();
      });
    }
    if (oldWidget.isActiveDeckSlide && !widget.isActiveDeckSlide) {
      widget.onControllerDisposed?.call(_pdfViewerController);
    }
  }

  void _syncPaginationFromController() {
    if (!widget.isActiveDeckSlide || !mounted) return;
    final total = _pdfViewerController.pageCount;
    if (total <= 0) return;
    final pn = _pdfViewerController.pageNumber;
    final cur = pn <= 0 ? 1 : pn.clamp(1, total);
    widget.onPaginationFromPdf?.call(widget.slideIndex, cur, total);
  }

  @override
  void dispose() {
    widget.onControllerDisposed?.call(_pdfViewerController);
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _error(
            snapshot.error is Exception
                ? (snapshot.error as Exception).toString().replaceFirst(
                    'Exception: ',
                    '',
                  )
                : "PDF ni ochib bo'lmadi",
          );
        }
        return SfPdfViewer.memory(
          snapshot.data!,
          controller: _pdfViewerController,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          pageLayoutMode: PdfPageLayoutMode.single,
          scrollDirection: PdfScrollDirection.horizontal,
          enableDoubleTapZooming: true,
          onDocumentLoaded: (details) {
            if (!widget.isActiveDeckSlide) return;
            final total = details.document.pages.count;
            if (total <= 0) return;
            final pn = _pdfViewerController.pageNumber;
            final cur = pn <= 0 ? 1 : pn.clamp(1, total);
            widget.onPaginationFromPdf?.call(widget.slideIndex, cur, total);
          },
          onPageChanged: (details) {
            if (!widget.isActiveDeckSlide) return;
            final total = _pdfViewerController.pageCount;
            if (total <= 0) return;
            widget.onPaginationFromPdf?.call(
              widget.slideIndex,
              details.newPageNumber.clamp(1, total),
              total,
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _loadBytes(String raw) async {
    final value = raw.trim();
    if (value.startsWith('data:application/pdf')) {
      final comma = value.indexOf(',');
      if (comma <= 0) throw Exception("PDF formati noto'g'ri.");
      try {
        return base64Decode(
          value.substring(comma + 1).replaceAll(RegExp(r'\s'), ''),
        );
      } catch (_) {
        throw Exception("PDF ni o'qib bo'lmadi.");
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null) throw Exception("PDF URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('bucket not found')) {
        throw Exception(
          "Cloudflare R2: content-assets bucket topilmadi. Faylni R2'ga yuklab, "
          "public URL bilan saqlang (bucket public bo'lsin).",
        );
      }
      throw Exception("PDF yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }

  Widget _error(String message) {
    return Container(
      color: const Color(0xFF0E4E8E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    required this.placeholderHeight,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    if (raw.isEmpty) return _placeholder();

    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex > 0) {
        final payload = raw
            .substring(commaIndex + 1)
            .replaceAll(RegExp(r'\s'), '');
        try {
          final bytes = base64Decode(payload);
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        } catch (_) {
          return _placeholder();
        }
      }
      return _placeholder();
    }

    final normalized = _normalizeImageUrl(raw);
    return Image.network(
      normalized,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  String _normalizeImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = getApiBaseUrl().replaceAll(RegExp(r'/+$'), '');
    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }

  Widget _placeholder() {
    final bg = ColoredBox(
      color: Colors.white.withValues(alpha: 0.16),
      child: const Center(
        child: Text(
          'Rasmni yuklab bo\'lmadi',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    if (height != null && height!.isFinite) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: bg,
      );
    }
    return SizedBox.expand(child: bg);
  }
}
