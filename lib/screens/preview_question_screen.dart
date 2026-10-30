// lib/screens/preview_question_screen.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kohntri_os_hq/question_types/question_factory.dart';

class PreviewQuestionScreen extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;

  const PreviewQuestionScreen({
    super.key,
    required this.questionData,
    this.questionIndex = 0,
  });

  @override
  State<PreviewQuestionScreen> createState() => _PreviewQuestionScreenState();
}

class _PreviewQuestionScreenState extends State<PreviewQuestionScreen> {
  bool _isAnswered = false;
  bool _hintUsed = false;
  bool _showExplanation = false;
  dynamic _lastAnswer;

  Map<String, dynamic> get d => widget.questionData;

  String get _question =>
      (d['question'] ?? d['text'] ?? '').toString();

  String? get _scenario {
    final v = d['scenario']?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _culturalContext {
    final v = d['cultural_context']?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _explanation {
    final v = d['explanation']?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _wrongConsequence {
    final v = d['wrong_consequence']?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _hint {
    final v = d['hint']?.toString() ??
        (d['type_data'] is Map
            ? (d['type_data'] as Map)['hint']?.toString()
            : null);
    return (v == null || v.isEmpty) ? null : v;
  }

  int get _points {
    final p = d['points'];
    if (p is int) return p;
    if (p is num) return p.toInt();
    return int.tryParse(p?.toString() ?? '') ?? 0;
  }

  String get _type => (d['type'] ?? d['question_type'] ?? 'multiple_choice')
      .toString();

  String get _difficulty => (d['difficulty'] ?? '').toString();

  String get _category => (d['category'] ?? '').toString();

  String? get _audioUrl {
    if (d['audio_url'] != null && d['audio_url'].toString().isNotEmpty) {
      return d['audio_url'].toString();
    }
    final td = d['type_data'];
    if (td is Map && td['audio_url'] != null) {
      final u = td['audio_url'].toString();
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  List<String> get _imageUrls {
    final raw = d['image_urls'] ?? d['image_url'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw != null && raw.toString().isNotEmpty) return [raw.toString()];
    return const [];
  }

  void _onAnswer(dynamic answer) {
    setState(() {
      _lastAnswer = answer;
      _isAnswered = true;
      _showExplanation = true;
    });
  }

  void _useHint() {
    if (_hint == null || _hintUsed) return;
    setState(() => _hintUsed = true);
  }

  void _resetPreview() {
    setState(() {
      _isAnswered = false;
      _hintUsed = false;
      _showExplanation = false;
      _lastAnswer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questionWidget = QuestionFactory.createQuestion(
      questionData: d,
      questionIndex: widget.questionIndex,
      onAnswer: _onAnswer,
      isAnswered: _isAnswered,
      hintUsed: _hintUsed,
      onHint: _hint != null ? _useHint : null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Preview (player view)'),
        actions: [
          TextButton(
            onPressed: _resetPreview,
            child: const Text('Reset'),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Meta strip (points, type, difficulty…) ──
          _MetaStrip(
            points: _points,
            type: _type,
            difficulty: _difficulty,
            category: _category,
          ),
          const SizedBox(height: 12),

          // ── Scenario (story beat, like in-app) ──
          if (_scenario != null) ...[
            _SectionCard(
              icon: Icons.auto_stories,
              title: 'Scenario',
              color: Colors.indigo,
              child: Text(
                _scenario!,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Images ──
          if (_imageUrls.isNotEmpty) ...[
            _SectionCard(
              icon: Icons.image_outlined,
              title: 'Image',
              color: Colors.teal,
              child: Column(
                children: _imageUrls
                    .map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const ListTile(
                              leading: Icon(Icons.broken_image),
                              title: Text('Image failed to load'),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Audio ──
          if (_audioUrl != null) ...[
            _SectionCard(
              icon: Icons.volume_up,
              title: 'Audio',
              color: Colors.deepPurple,
              child: AudioPlayerWidget(audioUrl: _audioUrl!),
            ),
            const SizedBox(height: 12),
          ],

          // ── Question prompt (always visible, same as player) ──
          if (_question.isNotEmpty) ...[
            _SectionCard(
              icon: Icons.help_outline,
              title: 'Question',
              color: Colors.blue,
              child: Text(
                _question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Interactive type UI (options / fill-blank / etc.) ──
          _SectionCard(
            icon: Icons.touch_app,
            title: 'Answer',
            color: Colors.green,
            child: questionWidget,
          ),

          // ── Hint (after use, or always show availability) ──
          if (_hint != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.lightbulb_outline,
              title: _hintUsed ? 'Hint' : 'Hint available',
              color: Colors.amber,
              trailing: !_hintUsed
                  ? TextButton(
                      onPressed: _useHint,
                      child: const Text('Reveal hint'),
                    )
                  : null,
              child: _hintUsed
                  ? Text(_hint!, style: const TextStyle(fontSize: 14, height: 1.4))
                  : Text(
                      'Tap “Reveal hint” (same as in-game when hint is used).',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
            ),
          ],

          // ── After answer: explanation / consequence ──
          if (_showExplanation) ...[
            const SizedBox(height: 12),
            if (_explanation != null)
              _SectionCard(
                icon: Icons.menu_book,
                title: 'Explanation',
                color: Colors.blueGrey,
                child: Text(
                  _explanation!,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ),
            if (_wrongConsequence != null) ...[
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.warning_amber,
                title: 'Wrong consequence',
                color: Colors.red,
                child: Text(
                  _wrongConsequence!,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ),
            ],
            if (_lastAnswer != null) ...[
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.check_circle_outline,
                title: 'Submitted answer (preview)',
                color: Colors.grey,
                child: Text(
                  _lastAnswer.toString(),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],

          // ── Cultural context (often after / alongside story) ──
          if (_culturalContext != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.public,
              title: 'Cultural context',
              color: Colors.brown,
              child: Text(
                _culturalContext!,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
          ],

          // ── Admin-only: raw fields still empty? ──
          const SizedBox(height: 20),
          ExpansionTile(
            title: const Text('All entry fields'),
            subtitle: const Text('Admin debug — full map'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _prettyMap(d),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _prettyMap(Map<String, dynamic> map) {
    final buf = StringBuffer();
    for (final e in map.entries) {
      buf.writeln('${e.key}: ${e.value}');
    }
    return buf.toString();
  }
}

class _MetaStrip extends StatelessWidget {
  final int points;
  final String type;
  final String difficulty;
  final String category;

  const _MetaStrip({
    required this.points,
    required this.type,
    required this.difficulty,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (points > 0) '$points pts',
      if (type.isNotEmpty) type,
      if (difficulty.isNotEmpty) difficulty,
      if (category.isNotEmpty) category,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
            ),
          )
          .toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

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
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _player.setSourceUrl(widget.audioUrl);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.resume();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inSeconds <= 0 ? 1.0 : _duration.inSeconds.toDouble();
    final value = _position.inSeconds.toDouble().clamp(0, max);

    return Column(
      children: [
        Slider(
          value: value.toDouble(),
          max: max,
          onChanged: (v) async {
            await _player.seek(Duration(seconds: v.toInt()));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _toggle,
            ),
            Text('${_position.inSeconds}s / ${_duration.inSeconds}s'),
          ],
        ),
      ],
    );
  }
}