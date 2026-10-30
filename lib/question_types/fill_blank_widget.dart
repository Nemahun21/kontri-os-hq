import 'package:flutter/material.dart';

class FillBlankWord {
  final String id;
  final String text;
  const FillBlankWord({required this.id, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FillBlankWord && id == other.id && text == other.text;

  @override
  int get hashCode => Object.hash(id, text);
}

class DragAndDropFillBlank extends StatefulWidget {
  final String? question;
  final List<String?> sentenceParts;
  final List<FillBlankWord> wordBank;
  final Map<int, String> correctAnswers;
  final void Function(Map<int, String> filled) onStateChanged;

  const DragAndDropFillBlank({
    super.key,
    this.question,
    required this.sentenceParts,
    required this.wordBank,
    required this.correctAnswers,
    required this.onStateChanged,
  });

  @override
  State<DragAndDropFillBlank> createState() => _DragAndDropFillBlankState();
}

class _DragAndDropFillBlankState extends State<DragAndDropFillBlank> {
  late Map<int, FillBlankWord?> _filledBlanks;
  late List<FillBlankWord> _remainingWords;
  late Map<String, FillBlankWord> _wordMap;

  @override
  void initState() {
    super.initState();
    _resetFromWidget();
  }

  @override
  void didUpdateWidget(covariant DragAndDropFillBlank oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reset when structure actually changes — NOT on every parent rebuild
    if (!_sameParts(oldWidget.sentenceParts, widget.sentenceParts) ||
        !_sameBank(oldWidget.wordBank, widget.wordBank)) {
      _resetFromWidget();
    }
  }

  bool _sameParts(List<String?> a, List<String?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameBank(List<FillBlankWord> a, List<FillBlankWord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].text != b[i].text) return false;
    }
    return true;
  }

  void _resetFromWidget() {
    _wordMap = {for (final w in widget.wordBank) w.id: w};
    _filledBlanks = {};
    for (var i = 0; i < widget.sentenceParts.length; i++) {
      if (widget.sentenceParts[i] == null) {
        _filledBlanks[i] = null;
      }
    }
    _remainingWords = List<FillBlankWord>.from(widget.wordBank);
  }

  void _notifyParent() {
    final filledMap = <int, String>{
      for (final e in _filledBlanks.entries)
        if (e.value != null) e.key: e.value!.id,
    };
    widget.onStateChanged(filledMap);
  }

  int? _nextEmptyBlankIndex() {
    final keys = _filledBlanks.keys.toList()..sort();
    for (final i in keys) {
      if (_filledBlanks[i] == null) return i;
    }
    return null;
  }

  void _placeWord(int blankIndex, String wordId) {
    final newWord = _wordMap[wordId];
    if (newWord == null) return;

    setState(() {
      final existing = _filledBlanks[blankIndex];
      if (existing != null &&
          !_remainingWords.any((w) => w.id == existing.id)) {
        _remainingWords.add(existing);
      }

      // Remove from bank
      _remainingWords.removeWhere((w) => w.id == wordId);

      // Clear if this word was in another blank
      for (final key in _filledBlanks.keys.toList()) {
        if (key != blankIndex && _filledBlanks[key]?.id == wordId) {
          _filledBlanks[key] = null;
        }
      }

      _filledBlanks[blankIndex] = newWord;
    });
    _notifyParent();
  }

  void _onWordTap(FillBlankWord word) {
    final blankIndex = _nextEmptyBlankIndex();
    if (blankIndex == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('All blanks filled. Tap a blank to clear one.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _placeWord(blankIndex, word.id);
  }

  void _clearBlank(int blankIndex) {
    final existing = _filledBlanks[blankIndex];
    if (existing == null) return;
    setState(() {
      _filledBlanks[blankIndex] = null;
      if (!_remainingWords.any((w) => w.id == existing.id)) {
        _remainingWords.add(existing);
      }
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final blankCount = _filledBlanks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionText(),
        const SizedBox(height: 10),
        _buildSentence(),
        const SizedBox(height: 16),
        if (blankCount == 0)
          Text(
            'No blanks in this sentence (check sentenceParts has null slots).',
            style: TextStyle(color: Colors.red[700], fontSize: 13),
          )
        else
          Text(
            'Tap a word to fill the next blank · drag onto a blank',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        const SizedBox(height: 8),
        _buildWordBank(),
      ],
    );
  }

  Widget _buildQuestionText() {
    final question = widget.question;
    if (question == null || question.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E86C1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E86C1).withOpacity(0.25)),
      ),
      child: Text(
        question,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSentence() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < widget.sentenceParts.length; i++)
          if (widget.sentenceParts[i] != null)
            Text(
              widget.sentenceParts[i]!,
              style: const TextStyle(fontSize: 18),
            )
          else
            _buildBlankTarget(i, _filledBlanks[i]),
      ],
    );
  }

  Widget _buildBlankTarget(int index, FillBlankWord? filledWord) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data.isNotEmpty,
      onAcceptWithDetails: (d) => _placeWord(index, d.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: filledWord != null ? () => _clearBlank(index) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 88, minHeight: 40),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hovering ? Colors.blue.shade50 : Colors.white,
                border: Border.all(
                  color: hovering ? Colors.blue : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filledWord?.text ?? '____',
                style: TextStyle(
                  fontSize: 16,
                  color: filledWord != null ? Colors.black87 : Colors.grey,
                  fontStyle:
                      filledWord != null ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordBank() {
    if (_remainingWords.isEmpty) {
      return Text(
        'All words placed · tap a blank to return a word',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final word in _remainingWords)
          Draggable<String>(
            data: word.id,
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  word.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _chip(word, onPressed: null),
            ),
            // Tap works: ActionChip is the child, not competing with long-press only
            child: _chip(word, onPressed: () => _onWordTap(word)),
          ),
      ],
    );
  }

  Widget _chip(FillBlankWord word, {required VoidCallback? onPressed}) {
    return ActionChip(
      label: Text(word.text, style: const TextStyle(fontSize: 15)),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
      onPressed: onPressed,
    );
  }
}