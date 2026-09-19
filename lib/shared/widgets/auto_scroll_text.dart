import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  const AutoScrollText({
    Key? key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  _AutoScrollTextState createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  bool _isOverflowing = false;

  void _checkOverflow(double availableWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth);

    final bool overflows = textPainter.didExceedMaxLines;
    if (_isOverflowing != overflows) {
      setState(() => _isOverflowing = overflows);
    }
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _isOverflowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Schedule a check after layout to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkOverflow(constraints.maxWidth);
        });

        if (_isOverflowing) {
          // Auto‑scroll marquee
          return SizedBox(
            height: _estimateTextHeight(),
            child: Marquee(
              text: widget.text,
              style: widget.style,
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: 20.0, // space between end and start
              velocity: 30.0,   // pixels per second
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 0.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          );
        } else {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          );
        }
      },
    );
  }

  // Helper to compute height of a single‑line text for the marquee container.
  double _estimateTextHeight() {
    final textPainter = TextPainter(
      text: TextSpan(text: 'A', style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.height;
  }
}