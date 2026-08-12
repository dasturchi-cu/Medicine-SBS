import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../widgets/option_button.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  final _apiBaseUrl = getApiBaseUrl();
  bool _loading = true;
  String _resolvedQuizId = "";
  String _quizTitle = "";
  String _emptyMessage = "Test topilmadi";
  List<_QuizQuestion> _questions = const [];
  int _index = 0;
  final Map<String, int> _answers = {};
  final DateTime _startedAt = DateTime.now();
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadQuiz);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  // ── navigatsiya + tanlash ──────────────────────────

  void _selectAnswer(String questionId, int optionIndex) {
    _advanceTimer?.cancel();
    setState(() => _answers[questionId] = optionIndex);
    // Tanlangach ko'karadi va biroz turib avtomatik keyingisiga o'tadi
    // (oxirgi savolда o'tmaydi — u yerda "Javobni yuborish" ishlatiladi).
    if (_index < _questions.length - 1) {
      _advanceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _index += 1);
      });
    }
  }

  void _goNext() {
    _advanceTimer?.cancel();
    if (_index < _questions.length - 1) setState(() => _index += 1);
  }

  void _goPrev() {
    _advanceTimer?.cancel();
    if (_index > 0) {
      setState(() => _index -= 1);
    } else {
      context.pop();
    }
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[_questions[i].id] == null) return i;
    }
    return -1;
  }

  Future<void> _submit() async {
    _advanceTimer?.cancel();
    final unanswered = _firstUnansweredIndex();
    if (unanswered != -1) {
      final answeredCount = _answers.length;
      final left = _questions.length - answeredCount;
      final goResult = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Testlarni to‘ldiring'),
          content: Text(
            'Hali $left ta savolga javob bermadingiz. '
            'Qolganini to‘ldirasizmi yoki shu holicha yuborasizmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('To‘ldirish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Baribir yuborish'),
            ),
          ],
        ),
      );
      if (goResult != true) {
        // To'ldirishga qaytamiz — birinchi javobsiz savolga o'tamiz.
        if (mounted) setState(() => _index = unanswered);
        return;
      }
    }
    _finishAndShowResults();
  }

  void _finishAndShowResults() {
    var correct = 0;
    for (final item in _questions) {
      final picked = _answers[item.id];
      if (picked != null && picked == item.correctIndex) correct += 1;
    }
    final totalQuestions = _questions.length;
    final score = ((correct / totalQuestions) * 100).round();
    final seconds = DateTime.now().difference(_startedAt).inSeconds;
    final minutes = (seconds <= 0 ? 0.0 : seconds / 60).toStringAsFixed(2);
    context.push(
      '${AppRoutes.result}?score=$score&total=100&quizId=$_resolvedQuizId&correct=$correct&totalQuestions=$totalQuestions&durationMin=$minutes',
    );
  }

  Future<void> _loadQuiz() async {
    if (_apiBaseUrl.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final repo = ref.read(courseRepositoryProvider);
    final relatedCourseId = repo.getCourseIdForLesson(widget.quizId);

    String? quizId = await _resolveQuizIdByLesson(widget.quizId);
    quizId ??= await _resolveQuizIdByCourse(relatedCourseId ?? "");
    quizId ??= await _resolveQuizIdDirect(widget.quizId);
    if (quizId == null || quizId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _emptyMessage = "Bu dars uchun test topilmadi";
        _loading = false;
      });
      return;
    }

    final meta = await _fetchQuizMeta(quizId);
    final questions = await _fetchQuestions(quizId);
    if (!mounted) return;
    setState(() {
      _resolvedQuizId = quizId!;
      _quizTitle = meta?.title ?? "Test sahifasi";
      _questions = questions;
      _emptyMessage = questions.isEmpty ? "Test bor, lekin savollar qo'shilmagan" : "Test topilmadi";
      _loading = false;
    });
  }

  Future<String?> _resolveQuizIdByLesson(String lessonId) async {
    final uri = Uri.parse('$_apiBaseUrl/api/v1/tests?lesson_id=$lessonId');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;
    final items = data['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    return (first['id'] ?? '').toString();
  }

  Future<String?> _resolveQuizIdDirect(String id) async {
    final uri = Uri.parse('$_apiBaseUrl/api/v1/tests/$id');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;
    return (data['id'] ?? '').toString();
  }

  Future<String?> _resolveQuizIdByCourse(String courseId) async {
    if (courseId.isEmpty) return null;
    final uri = Uri.parse('$_apiBaseUrl/api/v1/tests');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;
    final items = data['items'];
    if (items is! List || items.isEmpty) return null;
    for (final item in items.whereType<Map<String, dynamic>>()) {
      if ((item['course_id'] ?? '').toString() == courseId) {
        return (item['id'] ?? '').toString();
      }
    }
    return null;
  }

  Future<_QuizMeta?> _fetchQuizMeta(String id) async {
    final uri = Uri.parse('$_apiBaseUrl/api/v1/tests/$id');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;
    return _QuizMeta.fromJson(data);
  }

  Future<List<_QuizQuestion>> _fetchQuestions(String id) async {
    final uri = Uri.parse('$_apiBaseUrl/api/v1/tests/$id/questions');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items.whereType<Map<String, dynamic>>().map(_QuizQuestion.fromJson).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty || _resolvedQuizId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Test'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(_emptyMessage)),
      );
    }

    final question = _questions[_index];
    final selected = _answers[question.id];
    final isLast = _index == _questions.length - 1;
    final answeredCount = _answers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_quizTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _index > 0 ? 'Oldingi savol' : 'Chiqish',
          onPressed: _goPrev,
        ),
        actions: [
          // Keyingi savolga o'tish (ko'k)
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            color: const Color(0xFF1E6BB8),
            tooltip: 'Keyingi savol',
            onPressed: isLast ? null : _goNext,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Savol ${_index + 1} / ${_questions.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '$answeredCount / ${_questions.length} belgilandi',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        question.questionText,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Variantlar: to'liq en, bir-birining ostida (uzun qatorlar) ──
                  for (var i = 0; i < 4; i++) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: OptionButton(
                        label: String.fromCharCode('A'.codeUnitAt(0) + i),
                        text: question.options[i],
                        selected: selected == i,
                        onTap: () => _selectAnswer(question.id, i),
                      ),
                    ),
                    if (i < 3) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          // ── Javobni yuborish — doim pastda ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BB8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                child: const Text(
                  'Javobni yuborish',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizMeta {
  const _QuizMeta({required this.id, required this.title});

  final String id;
  final String title;

  factory _QuizMeta.fromJson(Map<String, dynamic> json) {
    return _QuizMeta(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Test sahifasi').toString(),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;

  factory _QuizQuestion.fromJson(Map<String, dynamic> json) {
    final correctOption = (json['correct_option'] ?? 'A').toString().toUpperCase();
    final correctIndex = ['A', 'B', 'C', 'D'].indexOf(correctOption);
    return _QuizQuestion(
      id: (json['id'] ?? '').toString(),
      questionText: (json['question_text'] ?? '').toString(),
      options: [
        (json['option_a'] ?? '').toString(),
        (json['option_b'] ?? '').toString(),
        (json['option_c'] ?? '').toString(),
        (json['option_d'] ?? '').toString(),
      ],
      correctIndex: correctIndex < 0 ? 0 : correctIndex,
    );
  }
}

