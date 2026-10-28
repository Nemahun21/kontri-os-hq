import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../admin_theme.dart';

class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    this.color = AdminColors.blue2,
    this.height = 160,
  });

  final List<int> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: BarChartPainter(values: values, color: color),
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  const BarChartPainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final maxVal = values.reduce(math.max).toDouble();
    final barWidth = size.width / values.length * 0.72;
    final xStep = size.width / values.length;
    final barPaint = Paint()..color = color;

    for (var i = 0; i < values.length; i++) {
      final value = values[i].toDouble();
      final left = i * xStep + (xStep - barWidth) / 2;
      final ratio = maxVal <= 0 ? 0 : value / maxVal;
      final barHeight = size.height * ratio;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class HBar extends StatelessWidget {
  const HBar({
    super.key,
    required this.value,
    required this.max,
    this.color = AdminColors.blue2,
  });

  final num value;
  final num max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: AdminColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: constraints.maxWidth * ratio,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }
}
