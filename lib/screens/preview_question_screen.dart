// lib/screens/preview_question_screen.dart
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/question_types/question_factory.dart';
import 'package:audioplayers/audioplayers.dart';

class PreviewQuestionScreen extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;

  const PreviewQuestionScreen({
    Key? key,
    required this.questionData,
    this.questionIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widget = QuestionFactory.createQuestion(
      questionData: questionData,
      questionIndex: questionIndex,
      onAnswer: (_) {},
      isAnswered: false,
      hintUsed: false,
      onHint: null,
    );

    // Extract audio URL
    String? audioUrl;
    if (questionData.containsKey('audio_url') && questionData['audio_url'] != null) {
      audioUrl = questionData['audio_url'];
    } else if (questionData.containsKey('type_data') && questionData['type_data'] != null) {
      final typeData = questionData['type_data'] as Map<String, dynamic>?;
      audioUrl = typeData?['audio_url'];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Audio player if present
            if (audioUrl != null && audioUrl.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Audio Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      AudioPlayerWidget(audioUrl: audioUrl),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Question widget
            SizedBox(
              height: 600, // or use flexible height
              child: widget,
            ),
          ],
        ),
      ),
    );
  }
}

// Simple audio player widget
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerComplete.listen((_) => setState(() => _isPlaying = false));
    _player.setSourceUrl(widget.audioUrl);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await _player.resume();
    setState(() => _isPlaying = true);
  }

  Future<void> _pause() async {
    await _player.pause();
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: _position.inSeconds.toDouble(),
          max: _duration.inSeconds.toDouble(),
          onChanged: (value) async {
            final position = Duration(seconds: value.toInt());
            await _player.seek(position);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _isPlaying ? _pause : _play,
            ),
            Text('${_position.inSeconds} / ${_duration.inSeconds}'),
          ],
        ),
      ],
    );
  }
}