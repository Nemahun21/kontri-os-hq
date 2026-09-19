import 'dart:async';
import 'package:flutter/material.dart';

class ChallengeTimer extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onTimeOut;
  final bool isActive;
  final VoidCallback? onTick; // optional callback each second

  const ChallengeTimer({
    Key? key,
    required this.initialSeconds,
    required this.onTimeOut,
    required this.isActive,
    this.onTick,
  }) : super(key: key);

  @override
  _ChallengeTimerState createState() => _ChallengeTimerState();
}

class _ChallengeTimerState extends State<ChallengeTimer> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant ChallengeTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset timer when question changes or active state toggles
    if (widget.isActive != oldWidget.isActive ||
        widget.initialSeconds != oldWidget.initialSeconds) {
      _resetTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        widget.onTick?.call();
      } else {
        timer.cancel();
        widget.onTimeOut();
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.initialSeconds;
    });
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Color based on remaining time
    Color timerColor = _remainingSeconds > 10
        ? Colors.green
        : _remainingSeconds > 5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: timerColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: timerColor,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$_remainingSeconds s',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: timerColor,
            ),
          ),
        ],
      ),
    );
  }
}