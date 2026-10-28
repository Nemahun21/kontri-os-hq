import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../admin_theme.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AdminColors.blue2,
    this.width = 80,
    this.height = 30,
  });

  final List<num> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: SparklinePainter(values: values, color: color),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  const SparklinePainter({required this.values, required this.color});

  final List<num> values;
  final Color color;

 @override
void paint(Canvas canvas, Size size) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  if (values.isEmpty) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint..color = color.withValues(alpha: 0.7),
    );
    return;
  }

  if (values.length == 1) {
    final point = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(point, 2.5, paint..color = color);
    return;
  }

  num max = values.first;
  num min = values.first;
  for (final v in values) {
    if (v > max) max = v;
    if (v < min) min = v;
  }
  final range = max - min == 0 ? 1 : max - min;

  final points = <Offset>[];

  for (var i = 0; i < values.length; i++) {
    final x = ((i / (values.length - 1)) * (size.width - 2)) + 1;
    final value = values[i];
    final normalized = (value - min) / range;
    final y = size.height - (normalized * (size.height - 2)) - 1;
    points.add(Offset(x, y));
  }

  final path = Path()..moveTo(points.first.dx, size.height);
  for (final point in points) {
    path.lineTo(point.dx, point.dy);
  }
  path.lineTo(points.last.dx, size.height);
  path.close();

  canvas.drawPath(path, fillPaint);
  canvas.drawPath(
    Path()..moveTo(points.first.dx, points.first.dy),
    paint,
  );

  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    canvas.drawLine(previous, current, paint);
  }

  final lastPoint = points.last;
  canvas.drawCircle(lastPoint, 2.5, Paint()..color = color);
}
  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
