import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration scrollDuration;
  final double spacing;

  const MarqueeText({
    Key? key,
    required this.text,
    required this.style,
    this.scrollDuration = const Duration(seconds: 5),
    this.spacing = 30.0,
  }) : super(key: key);

  @override
  _MarqueeTextState createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If text changes, re-evaluate scrolling
    if (oldWidget.text != widget.text || 
        oldWidget.style != widget.style ||
        oldWidget.scrollDuration != widget.scrollDuration ||
        oldWidget.spacing != widget.spacing) {
      _shouldScroll = false;
      _animation = null;
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure text width
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = textPainter.width;
        final availableWidth = constraints.maxWidth;

        // If text fits, show static text
        if (textWidth <= availableWidth) {
          if (_shouldScroll) {
            _controller.stop();
            _shouldScroll = false;
            _animation = null;
          }
          return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Text overflows – need scrolling
        if (!_shouldScroll) {
          // Setup animation only once
          final scrollDistance = textWidth + widget.spacing;
          _controller.duration = widget.scrollDuration;
          _animation = Tween<double>(begin: 0, end: -scrollDistance).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          );
          _controller.repeat();
          _shouldScroll = true;
        }

        // Safety check: if animation not yet created (shouldn't happen)
        if (_animation == null) {
          return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.ellipsis,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _animation!,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animation!.value, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.text, style: widget.style),
                    SizedBox(width: widget.spacing),
                    Text(widget.text, style: widget.style),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}