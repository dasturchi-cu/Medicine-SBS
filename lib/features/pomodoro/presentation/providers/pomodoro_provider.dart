import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PomodoroSessionType { focus, breakTime }

class PomodoroState {
  const PomodoroState({
    required this.sessionType,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.soundOn,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.pomodoroCount,
    required this.completedSessions,
  });

  factory PomodoroState.initial() {
    return const PomodoroState(
      sessionType: PomodoroSessionType.focus,
      focusMinutes: 25,
      breakMinutes: 5,
      soundOn: true,
      totalSeconds: 25 * 60,
      remainingSeconds: 25 * 60,
      isRunning: false,
      pomodoroCount: 1,
      completedSessions: 0,
    );
  }

  final PomodoroSessionType sessionType;
  final int focusMinutes;
  final int breakMinutes;
  final bool soundOn;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final int pomodoroCount;
  final int completedSessions;

  PomodoroState copyWith({
    PomodoroSessionType? sessionType,
    int? focusMinutes,
    int? breakMinutes,
    bool? soundOn,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    int? pomodoroCount,
    int? completedSessions,
  }) {
    return PomodoroState(
      sessionType: sessionType ?? this.sessionType,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      soundOn: soundOn ?? this.soundOn,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }

  double get progress {
    if (totalSeconds == 0) return 0;
    final elapsed = (totalSeconds - remainingSeconds).clamp(0, totalSeconds);
    return elapsed / totalSeconds;
  }
}

final pomodoroProvider = NotifierProvider<PomodoroController, PomodoroState>(
  PomodoroController.new,
);

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _timer;

  @override
  PomodoroState build() {
    ref.onDispose(_cancelTimer);
    return PomodoroState.initial();
  }

  void setSessionType(PomodoroSessionType type) {
    if (state.sessionType == type) return;
    _cancelTimer();
    final duration = _durationFor(type);
    state = state.copyWith(
      sessionType: type,
      totalSeconds: duration,
      remainingSeconds: duration,
      isRunning: false,
    );
  }

  void updateFocusMinutes(int minutes) {
    final clamped = minutes.clamp(1, 90);
    final isFocus = state.sessionType == PomodoroSessionType.focus;
    state = state.copyWith(
      focusMinutes: clamped,
      totalSeconds: isFocus ? clamped * 60 : state.totalSeconds,
      remainingSeconds: isFocus ? clamped * 60 : state.remainingSeconds,
      isRunning: isFocus ? false : state.isRunning,
    );
    if (isFocus) _cancelTimer();
  }

  void updateBreakMinutes(int minutes) {
    final clamped = minutes.clamp(1, 45);
    final isBreak = state.sessionType == PomodoroSessionType.breakTime;
    state = state.copyWith(
      breakMinutes: clamped,
      totalSeconds: isBreak ? clamped * 60 : state.totalSeconds,
      remainingSeconds: isBreak ? clamped * 60 : state.remainingSeconds,
      isRunning: isBreak ? false : state.isRunning,
    );
    if (isBreak) _cancelTimer();
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundOn: value);
  }

  void start() {
    if (state.isRunning) return;
    if (state.remainingSeconds <= 0) {
      reset();
    }
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (!state.isRunning) return;
    _cancelTimer();
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _cancelTimer();
    final duration = _durationFor(state.sessionType);
    state = state.copyWith(
      isRunning: false,
      totalSeconds: duration,
      remainingSeconds: duration,
    );
  }

  void _tick() {
    final seconds = state.remainingSeconds;
    if (seconds <= 1) {
      _cancelTimer();
      final finishedFocus = state.sessionType == PomodoroSessionType.focus;
      state = state.copyWith(
        remainingSeconds: 0,
        isRunning: false,
        completedSessions: state.completedSessions + 1,
        pomodoroCount: finishedFocus
            ? state.pomodoroCount + 1
            : state.pomodoroCount,
      );
      return;
    }

    state = state.copyWith(remainingSeconds: seconds - 1);
  }

  int _durationFor(PomodoroSessionType type) {
    return type == PomodoroSessionType.focus
        ? state.focusMinutes * 60
        : state.breakMinutes * 60;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
