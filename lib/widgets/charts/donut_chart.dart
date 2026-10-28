import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../admin_theme.dart';

class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 96,
    this.centerLabel,
  });

  final List<DonutSegment> segments;
  final double size;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DonutPainter(segments: segments, centerLabel: centerLabel),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  const DonutPainter({required this.segments, this.centerLabel});

  final List<DonutSegment> segments;
  final String? centerLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final total = segments.fold<num>(0, (sum, item) => sum + item.value);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (total <= 0 || segments.isEmpty) {
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AdminColors.border
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, base);
      final text = TextPainter(
        text: const TextSpan(text: '0', style: TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - text.height / 2));
      return;
    }

    double startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.value / total) * math.pi * 2;
      final paint = ringPaint..color = segment.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    final gapPaint = Paint()..color = AdminColors.bg..style = PaintingStyle.stroke..strokeWidth = 4;
    final gapRadius = radius + 0.3;
    final gapStart = -math.pi / 2;
    final gapEnd = startAngle;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: gapRadius),
      gapStart,
      gapEnd,
      false,
      gapPaint,
    );

    final label = centerLabel ?? total.toString();
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - text.height / 2));
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.centerLabel != centerLabel;
  }
}
