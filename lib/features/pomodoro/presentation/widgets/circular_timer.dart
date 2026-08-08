import 'dart:math' as math;

import 'package:flutter/material.dart';

class CircularTimer extends StatefulWidget {
  const CircularTimer({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.isRunning,
    required this.sessionLabel,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;
  final String sessionLabel;

  @override
  State<CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends State<CircularTimer>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  double _lastProgress = 0;

  @override
  void initState() {
    super.initState();
    _lastProgress = _targetProgress;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _progressAnimation = AlwaysStoppedAnimation<double>(_lastProgress);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant CircularTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newProgress = _targetProgress;
    if ((_lastProgress - newProgress).abs() > 0.0001) {
      _progressAnimation = Tween<double>(begin: _lastProgress, end: newProgress)
          .animate(
            CurvedAnimation(
              parent: _progressController,
              curve: Curves.easeOutCubic,
            ),
          );
      _lastProgress = newProgress;
      _progressController
        ..reset()
        ..forward();
    }
    _syncPulse();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  double get _targetProgress {
    if (widget.totalSeconds <= 0) return 0;
    final elapsed = (widget.totalSeconds - widget.remainingSeconds).clamp(
      0,
      widget.totalSeconds,
    );
    return elapsed / widget.totalSeconds;
  }

  void _syncPulse() {
    if (widget.isRunning) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_progressController, _pulseController]),
      builder: (context, _) {
        final pulse = widget.isRunning
            ? (1 + (_pulseController.value * 0.02))
            : 1.0;
        final progress = _progressAnimation.value;

        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64D2FF).withValues(alpha: 0.20),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _TimerRingPainter(progress: progress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(widget.remainingSeconds),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.sessionLabel.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width / 2) - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF8A7CFF), Color(0xFF57D6FF), Color(0xFF8A7CFF)],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, 0, 2 * math.pi * progress, false, progressPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
