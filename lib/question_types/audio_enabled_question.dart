import 'package:flutter/material.dart';
import 'audio_player_widget.dart';

class AudioEnabledQuestion extends StatelessWidget {
  final Widget child;
  final String? audioUrl;

  final double? trimStart;
  final double? trimEnd;

  const AudioEnabledQuestion({
    Key? key,
    required this.child,
    this.audioUrl,
    this.trimStart,
    this.trimEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no audio, just return the child
    if (audioUrl == null || audioUrl!.isEmpty) {
      return child;
    }

    // Otherwise, place audio player above child
    return Column(
      children: [
        AudioPlayerWidget(
          audioUrl: audioUrl!,
          trimStart: trimStart,
          trimEnd: trimEnd,
          height: 45,
        ),
       const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}
