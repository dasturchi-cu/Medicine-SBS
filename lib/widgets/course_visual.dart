import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

class CourseVisual extends StatefulWidget {
  const CourseVisual({super.key, required this.kind, this.imageUrl = ''});

  /// e.g. 'eeg', 'brain', 'medical', 'enmg'
  final String kind;
  final String imageUrl;

  @override
  State<CourseVisual> createState() => _CourseVisualState();
}

class _CourseVisualState extends State<CourseVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawImage = widget.imageUrl.trim();
    if (rawImage.isNotEmpty) {
      if (rawImage.startsWith('data:image')) {
        final comma = rawImage.indexOf(',');
        if (comma > 0) {
          try {
            final bytes = base64Decode(rawImage.substring(comma + 1));
            return Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F0FF),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(bytes, fit: BoxFit.cover),
            );
          } catch (_) {}
        }
      }
      if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            rawImage,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Color(0xFF1E6BB8)),
          ),
        );
      }
    }

    if (widget.kind == 'umumiy_bachelor') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/umumiy_nevrologiya_bakalavr.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (widget.kind == 'xususiy_bachelor') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/xususiy_nevrologiya_bakalavr.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (widget.kind == 'xususiy_doctors') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage(
              'assets/images/xususiy_nevrologiya_shifokorlar.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (widget.kind == 'epileptologiya_img') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/epileptologiya.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (widget.kind == 'eeg_img') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/eeg.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (widget.kind == 'enmg_img') {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/enmg.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            painter: _VisualPainter(kind: widget.kind, t: t),
          ),
        );
      },
    );
  }
}

class _VisualPainter extends CustomPainter {
  _VisualPainter({required this.kind, required this.t});

  final String kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const blue = Color(0xFF1E6BB8);
    const navy = Color(0xFF0E4E8B);
    const mint = Color(0xFF2E7D32);
    const yellow = Color(0xFFFFC107);
    const pink = Color(0xFFEF6C9A);

    // subtle blob background
    final blob = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.25),
      14 + 2 * t,
      blob,
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.85),
      10 + 2 * (1 - t),
      blob,
    );

    if (kind == 'eeg') {
      // monitor + animated wave (EKG/EEG vibe)
      final frame = Paint()
        ..color = navy.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = navy.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 12, size.width - 16, size.height - 24),
        const Radius.circular(10),
      );
      canvas.drawRRect(r, frame);
      canvas.drawRRect(r, border);

      final wave = Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final amp = 4.8 + 3.6 * t;
      final left = 12.0;
      final right = size.width - 12.0;
      final top = 18.0;
      final bottom = size.height - 18.0;
      final midY = (top + bottom) / 2;
      for (int i = 0; i <= 24; i++) {
        final x = left + (right - left) * (i / 24);
        final phase = (i / 24) * pi * 2 + (t * pi);
        final y = midY + sin(phase) * amp * 0.25;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, wave);

      // small dot moving along the wave
      final dotX = left + (right - left) * t;
      final dotY = midY + sin((t * pi * 2) + (t * pi)) * amp * 0.25;
      canvas.drawCircle(Offset(dotX, dotY), 2.6, Paint()..color = yellow);
      return;
    }

    if (kind == 'medical') {
      // stethoscope-ish + pulse
      final p = Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      final y = 18 + 2 * t;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx, y + 10),
          width: 22,
          height: 22,
        ),
        pi,
        pi,
        false,
        p,
      );
      canvas.drawLine(
        Offset(center.dx - 11, y + 10),
        Offset(center.dx - 11, y + 18),
        p,
      );
      canvas.drawLine(
        Offset(center.dx + 11, y + 10),
        Offset(center.dx + 11, y + 18),
        p,
      );
      canvas.drawCircle(
        Offset(center.dx - 11, y + 20),
        2.2,
        Paint()..color = pink,
      );
      canvas.drawCircle(
        Offset(center.dx + 11, y + 20),
        2.2,
        Paint()..color = pink,
      );

      // small pulse line
      final pulse = Paint()
        ..color = mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final px = 14.0;
      final py = size.height - 18.0;
      final pulsePath = Path()
        ..moveTo(px, py)
        ..lineTo(px + 8, py)
        ..lineTo(px + 12, py - 6 - 3 * t)
        ..lineTo(px + 16, py + 4 + 2 * t)
        ..lineTo(px + 22, py - 2)
        ..lineTo(px + 28, py)
        ..lineTo(px + 34, py);
      canvas.drawPath(pulsePath, pulse);
      return;
    }

    if (kind == 'enmg') {
      // nerve impulse: bolt + dotted line
      final dx = (t - 0.5) * 2.0;
      final bolt = Paint()..color = yellow.withValues(alpha: 0.95);
      final path = Path()
        ..moveTo(center.dx - 6, center.dy - 10)
        ..lineTo(center.dx + 2 + dx, center.dy - 10)
        ..lineTo(center.dx - 2, center.dy + 2)
        ..lineTo(center.dx + 6, center.dy + 2)
        ..lineTo(center.dx - 2 - dx, center.dy + 12)
        ..lineTo(center.dx + 1, center.dy + 2)
        ..lineTo(center.dx - 6, center.dy + 2)
        ..close();
      canvas.drawPath(path, bolt);

      final dots = Paint()..color = blue.withValues(alpha: 0.85);
      for (int i = 0; i < 5; i++) {
        final x = 12.0 + i * 7.0 + (t * 1.5);
        final y = size.height * 0.24 + sin(t * pi * 2 + i) * 1.2;
        canvas.drawCircle(Offset(x, y), 1.4, dots);
      }
      return;
    }

    // brain-ish: lobes + animated synapses
    final fill = Paint()..color = blue.withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final brainR = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 1),
      width: 30,
      height: 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(brainR, const Radius.circular(12)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(brainR, const Radius.circular(12)),
      stroke,
    );

    final syn = Paint()..color = pink.withValues(alpha: 0.95);
    final nodes = [
      Offset(center.dx - 9, center.dy - 3),
      Offset(center.dx - 2, center.dy - 8),
      Offset(center.dx + 6, center.dy - 6),
      Offset(center.dx + 10, center.dy + 1),
      Offset(center.dx + 2, center.dy + 9),
      Offset(center.dx - 7, center.dy + 7),
    ];
    for (int i = 0; i < nodes.length; i++) {
      final o =
          nodes[i] +
          Offset(sin(t * pi * 2 + i) * 1.0, cos(t * pi * 2 + i) * 1.0);
      canvas.drawCircle(o, 2.1, syn);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.t != t;
}
