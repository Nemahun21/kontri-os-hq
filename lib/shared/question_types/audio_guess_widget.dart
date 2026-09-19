import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioGuessWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final Function(dynamic) onAnswer;
  final bool isAnswered;

  const AudioGuessWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.onAnswer,
    required this.isAnswered,
  }) : super(key: key);

  @override
  _AudioGuessWidgetState createState() => _AudioGuessWidgetState();
}

class _AudioGuessWidgetState extends State<AudioGuessWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _hasPlayed = false;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _hasPlayed = true;
          }
        });
      }
    });

    // Report text changes to parent (enables global submit button)
    _answerController.addListener(() {
      if (!widget.isAnswered) {
        widget.onAnswer(_answerController.text);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A5276).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        widget.questionData['category'] ?? 'Quiz',
        style: const TextStyle(
          color: Color(0xFF1A5276),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final audioUrl = widget.questionData['type_data']?['audio_url'] as String? ?? '';
    final trimStart = (widget.questionData['type_data']?['trim_start'] as num?)?.toDouble() ?? 0.0;
    final trimEnd = (widget.questionData['type_data']?['trim_end'] as num?)?.toDouble();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: _isPlaying
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  )
                : const Icon(Icons.play_circle_filled, size: 30, color: Colors.blue),
            onPressed: widget.isAnswered
                ? null
                : () async {
                    if (_isPlaying) {
                      await _player.stop();
                    } else {
                      await _player.setSource(UrlSource(audioUrl));
                      if (trimStart > 0) {
                        await _player.seek(Duration(milliseconds: (trimStart * 1000).round()));
                      }
                      await _player.resume();

                      if (trimEnd != null && trimEnd > trimStart) {
                        _player.onPositionChanged.listen((pos) {
                          if (pos.inMilliseconds >= (trimEnd * 1000).round()) {
                            _player.stop();
                          }
                        });
                      }
                    }
                  },
          ),
          const SizedBox(width: 8),
          Text(
            _isPlaying ? 'Playing...' : (_hasPlayed ? 'Replay' : 'Tap to play'),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
          _buildAudioPlayer(),
      //  _buildCategoryChip(),
        const SizedBox(height: 20),
        _buildQuestionCard(widget.questionData['question']),
        //const SizedBox(height: 30),
      
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _answerController,
              enabled: !widget.isAnswered,
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}