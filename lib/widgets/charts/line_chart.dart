import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../admin_theme.dart';

class LineSeries {
  const LineSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<int> values;
  final Color color;
}

class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.series,
    this.dates,
    this.height = 180,
  });

  final List<LineSeries> series;
  final List<DateTime>? dates;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: LineChartPainter(series: series, dates: dates),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  const LineChartPainter({required this.series, this.dates});

  final List<LineSeries> series;
  final List<DateTime>? dates;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = AdminColors.border;
    final gridStep = size.height / 4;

    for (var i = 0; i <= 4; i++) {
      final y = i * gridStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint..strokeWidth = 1);
    }

    if (series.isEmpty) {
      return;
    }

    final allValues = <int>[];
    for (final item in series) {
      allValues.addAll(item.values);
    }
    if (allValues.isEmpty) {
      return;
    }

    final max = allValues.reduce((a, b) => a > b ? a : b).toDouble();
    final min = allValues.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (max - min).abs() == 0 ? 1.0 : (max - min).abs();

    for (final item in series) {
      final path = Path();
      final points = <Offset>[];

      for (var i = 0; i < item.values.length; i++) {
        final value = item.values[i].toDouble();
        final x = item.values.length == 1 ? size.width / 2 : (i / (item.values.length - 1)) * size.width;
        final y = size.height - ((value - min) / range) * (size.height - 12) - 6;
        points.add(Offset(x, y));
      }

      if (points.isEmpty) {
        continue;
      }

      path.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      final strokePaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, strokePaint);

      if (points.length == 1) {
        canvas.drawCircle(points.first, 3, Paint()..color = item.color);
      }
    }

    if (dates != null && dates!.isNotEmpty) {
      final step = dates!.length == 1 ? 0.0 : size.width / (dates!.length - 1);
      for (var i = 0; i < dates!.length; i++) {
        final x = dates!.length == 1 ? size.width / 2 : i * step;
       if (i % math.max(1, (dates!.length / 4).ceil()) == 0){
          final label = dates![i].day.toString();
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(color: AdminColors.textSecondary, fontSize: 9),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, size.height + 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.dates != dates;
  }
}
