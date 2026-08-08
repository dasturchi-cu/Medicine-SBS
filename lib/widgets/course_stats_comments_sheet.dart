import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/data/models/comment_models.dart';
import '../core/state/auth_controller.dart';
import '../core/di/providers.dart';
import '../core/state/comments_state.dart';
import '../core/state/progress_controller.dart';

class CourseStatsCommentsSheet extends ConsumerStatefulWidget {
  const CourseStatsCommentsSheet({
    super.key,
    required this.courseId,
    required this.courseTitleUz,
    this.useFeedbackApi = false,
  });

  final String courseId;
  final String courseTitleUz;
  final bool useFeedbackApi;

  @override
  ConsumerState<CourseStatsCommentsSheet> createState() => _CourseStatsCommentsSheetState();
}

class _CourseStatsCommentsSheetState extends ConsumerState<CourseStatsCommentsSheet> {
  final _controller = TextEditingController();
  final _replyController = TextEditingController();
  int _enrolledCount = 0;
  int _commentsCount = 0;
  double _ratingAvg = 0;
  int _ratingCount = 0;
  int _myRating = 0;
  bool _sending = false;
  bool _ratingLoading = false;
  bool _feedbackApiMissing = false;
  String? _replyToCommentId;
  bool _statsLoading = true;
  String? _statsError;
  final Set<String> _pendingLikeCommentIds = <String>{};
  final Map<String, bool> _optimisticLikedByMe = <String, bool>{};
  final Map<String, int> _optimisticLikesCount = <String, int>{};

  @override
  void dispose() {
    _controller.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCourseStats();
  }

  @override
  void didUpdateWidget(covariant CourseStatsCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId) {
      _loadCourseStats();
    }
  }

  Future<void> _loadCourseStats() async {
    final baseUrl = getApiBaseUrl();
    final userId = (ref.read(authControllerProvider).userId ?? '').trim();
    if (baseUrl.isEmpty || widget.courseId.trim().isEmpty) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _statsLoading = true;
        _statsError = null;
      });
    }
    try {
      final statsUri = widget.useFeedbackApi
          ? Uri.parse('$baseUrl/api/v1/feedback/${widget.courseId}/stats').replace(
              queryParameters: userId.isEmpty ? null : {'user_id': userId},
            )
          : Uri.parse('$baseUrl/api/v1/courses/${widget.courseId}/stats').replace(
              queryParameters: userId.isEmpty ? null : {'user_id': userId},
            );
      debugPrint('[API][courses.stats][request] uri=$statsUri');
      final response = await http
          .get(statsUri)
          .timeout(const Duration(seconds: 12));
      debugPrint('[API][courses.stats][response] status=${response.statusCode}');
      if (widget.useFeedbackApi && response.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _statsLoading = false;
          _statsError = null;
          _feedbackApiMissing = true;
        });
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Kurs statistikasi yuklanmadi (${response.statusCode}).');
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception("Statistika JSON emas.");
      }
      final enrolled = int.tryParse((body['enrolled_count'] ?? '0').toString()) ?? 0;
      final comments = int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0;
      final ratingAvg = double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0;
      final ratingCount = int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0;
      final rawMy = body['my_rating'] ?? body['myRating'];
      final myRating = rawMy == null ? 0 : (int.tryParse(rawMy.toString()) ?? 0);
      if (!mounted) return;
      setState(() {
        _enrolledCount = widget.useFeedbackApi ? 0 : enrolled;
        _commentsCount = comments;
        _ratingAvg = ratingAvg;
        _ratingCount = ratingCount;
        _myRating = myRating;
        _statsLoading = false;
        _statsError = null;
        _feedbackApiMissing = false;
      });
    } catch (error) {
      debugPrint('[API][courses.stats][error] $error');
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _statsError = error.toString();
      });
    }
  }

  Future<void> _submitRating(int stars) async {
    final auth = ref.read(authControllerProvider);
    final userId = (auth.userId ?? '').trim();
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;
    final prevMy = _myRating;
    final prevCount = _ratingCount;
    final prevAvg = _ratingAvg;
    final isNewVote = prevMy == 0;
    final optimisticCount = isNewVote ? prevCount + 1 : prevCount;
    final optimisticAvg = optimisticCount == 0
        ? stars.toDouble()
        : (((prevAvg * prevCount) - prevMy + stars) / optimisticCount);
    setState(() {
      _ratingLoading = true;
      _myRating = stars;
      _ratingCount = optimisticCount;
      _ratingAvg = optimisticAvg.clamp(0, 5).toDouble();
    });
    try {
      final ratePath = widget.useFeedbackApi
          ? '/api/v1/feedback/${widget.courseId}/rate'
          : '/api/v1/courses/${widget.courseId}/rate';
      debugPrint('[API][courses.rate][request] path=$ratePath userId=$userId stars=$stars');
      final response = await http
          .post(
            Uri.parse('$baseUrl$ratePath'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'stars': stars}),
          )
          .timeout(const Duration(seconds: 12));
      debugPrint('[API][courses.rate][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (widget.useFeedbackApi && response.statusCode == 404) {
          throw Exception('Feedback API hali backendda yoq. Backendni yangilang.');
        }
        var msg = 'Baholash rad etildi (${response.statusCode}).';
        try {
          final b = jsonDecode(response.body);
          if (b is Map && b['detail'] != null) msg = b['detail'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
      if (!mounted) return;
      await _loadCourseStats();
      if (!mounted) return;
      setState(() {
        if (_myRating == 0 && stars >= 1 && stars <= 5) {
          _myRating = stars;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _myRating = prevMy;
        _ratingCount = prevCount;
        _ratingAvg = prevAvg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.userId ?? '';
    final hasCourseId = widget.courseId.trim().isNotEmpty;

    if (!hasCourseId) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.courseTitleUz,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text("Bu reklama kursga ulanmagan. Izoh va baholash uchun kurs tanlangan bo'lishi kerak."),
            ],
          ),
        ),
      );
    }

    final commentsAsync = ref.watch(
      courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
    );
    final progress = ref.watch(progressControllerProvider).byCourseId[widget.courseId];
    final completed = progress?.completedLessonIds.length ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.courseTitleUz,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            if (_statsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_statsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _statsError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                ),
              )
            else if (widget.useFeedbackApi)
              Row(
                children: [
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: '$_commentsCount izoh',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.star_border,
                    label: '$_ratingCount baho',
                  ),
                ],
              )
            else
              Row(
                children: [
                  _StatChip(
                    icon: Icons.people_alt_outlined,
                    label: '$_enrolledCount talaba',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: '$completed yakunlangan',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: '$_commentsCount izoh',
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Baholash:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 8),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: _ratingLoading || _feedbackApiMissing ? null : () => _submitRating(i),
                    icon: Icon(
                      i <= _myRating ? Icons.star : Icons.star_border,
                      color: i <= _myRating ? Colors.amber.shade700 : Colors.amber,
                      size: i <= _myRating ? 26 : 24,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                Text(
                  '${_ratingAvg.toStringAsFixed(1)} ($_ratingCount)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (_feedbackApiMissing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Yulduzcha baholash backendga hali deploy qilinmagan (feedback endpoint 404).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Izohlar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('Izohlarni yuklashda xatolik.')),
                data: (comments) {
                  final rootComments = comments.where((item) => item.parentId == null || item.parentId!.isEmpty).toList(growable: true)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final repliesByParent = <String, List<AppCommentItem>>{};
                  for (final item in comments.where((item) => item.parentId != null && item.parentId!.isNotEmpty)) {
                    repliesByParent.putIfAbsent(item.parentId!, () => <AppCommentItem>[]).add(item);
                  }
                  for (final list in repliesByParent.values) {
                    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  }
                  if (rootComments.isEmpty) {
                    return Text(
                      'Hozircha izoh yo‘q',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: rootComments.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = rootComments[i];
                      final replies = repliesByParent[c.id] ?? const <AppCommentItem>[];
                      final showReplyInput = _replyToCommentId == c.id;
                      final likedByMe = _optimisticLikedByMe[c.id] ?? c.likedByMe;
                      final likesCount = _optimisticLikesCount[c.id] ?? c.likesCount;
                      final likePending = _pendingLikeCommentIds.contains(c.id);
                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.authorName,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.text,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: userId.isEmpty || likePending
                                        ? null
                                        : () async {
                                            final nextLiked = !likedByMe;
                                            final nextCount = nextLiked
                                                ? likesCount + 1
                                                : (likesCount > 0 ? likesCount - 1 : 0);
                                            setState(() {
                                              _pendingLikeCommentIds.add(c.id);
                                              _optimisticLikedByMe[c.id] = nextLiked;
                                              _optimisticLikesCount[c.id] = nextCount;
                                            });
                                            try {
                                              await ref.read(commentsRepositoryProvider).toggleLike(
                                                    commentId: c.id,
                                                    userId: userId,
                                                  );
                                              ref.invalidate(
                                                courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                                              );
                                            } catch (e) {
                                              if (mounted) {
                                                setState(() {
                                                  _optimisticLikedByMe.remove(c.id);
                                                  _optimisticLikesCount.remove(c.id);
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e.toString().contains('SocketException') ||
                                                              e.toString().contains('ClientException') ||
                                                              e.toString().contains('TimeoutException')
                                                          ? "Like saqlanmadi. Internet ulanishini tekshiring."
                                                          : "Like saqlanmadi: ${e.toString()}",
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                _optimisticLikedByMe.remove(c.id);
                                                _optimisticLikesCount.remove(c.id);
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() => _pendingLikeCommentIds.remove(c.id));
                                              } else {
                                                _pendingLikeCommentIds.remove(c.id);
                                              }
                                            }
                                          },
                                    icon: Icon(
                                      likedByMe ? Icons.favorite : Icons.favorite_border,
                                      size: 20,
                                      color: likedByMe ? Colors.red.shade600 : Colors.black45,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$likesCount'),
                                  if (c.likedByAdmin) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Admin like bosdi',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: userId.isEmpty
                                        ? null
                                        : () {
                                            setState(() {
                                              _replyToCommentId = showReplyInput ? null : c.id;
                                              if (!showReplyInput) {
                                                _replyController.clear();
                                              }
                                            });
                                          },
                                    child: Text('Javob (${c.repliesCount})'),
                                  ),
                                ],
                              ),
                              if (showReplyInput) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        decoration: const InputDecoration(
                                          hintText: 'Javob yozing...',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () async {
                                        final text = _replyController.text.trim();
                                        if (text.isEmpty || userId.isEmpty) return;
                                        try {
                                          await ref.read(commentsRepositoryProvider).addReply(
                                                commentId: c.id,
                                                userId: userId,
                                                authorName: auth.name.trim().isEmpty
                                                    ? 'Foydalanuvchi'
                                                    : auth.name.trim(),
                                                text: text,
                                              );
                                          _replyController.clear();
                                          setState(() => _replyToCommentId = null);
                                          ref.invalidate(
                                            courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                                          );
                                          if (mounted) setState(() => _commentsCount += 1);
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(e.toString())),
                                          );
                                        }
                                      },
                                      child: const Text('Javob'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (replies.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.only(left: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                                    ),
                                  ),
                                  child: Column(
                                    children: replies
                                        .map(
                                          (reply) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        reply.authorName,
                                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(reply.text),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Izoh yozing...',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BB8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _sending
                        ? null
                        : () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty || userId.isEmpty) return;
                      setState(() => _sending = true);
                      try {
                        await ref.read(commentsRepositoryProvider).addComment(
                              courseKey: widget.courseId,
                              userId: userId,
                              authorName: auth.name.trim().isEmpty
                                  ? 'Foydalanuvchi'
                                  : auth.name.trim(),
                              text: text,
                            );
                        _controller.clear();
                        if (mounted) setState(() => _commentsCount += 1);
                        ref.invalidate(
                          courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                        );
                        unawaited(_loadCourseStats());
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
                    },
                    child: const Text(
                      'Yuborish',
                      style: TextStyle(fontWeight: FontWeight.w900),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

