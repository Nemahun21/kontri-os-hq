import 'package:flutter/material.dart';

class FillBlankWord {
  final String id;
  final String text;
  const FillBlankWord({required this.id, required this.text});
}

class DragAndDropFillBlank extends StatefulWidget {
  final String? question;  
  final List<String?> sentenceParts;
  final List<FillBlankWord> wordBank;
  final Map<int, String> correctAnswers; // not used for scoring now, but kept for potential UI
  final void Function(Map<int, String> filled) onStateChanged;

  const DragAndDropFillBlank({
    Key? key,
    this.question,
    required this.sentenceParts,
    required this.wordBank,
    required this.correctAnswers,
    required this.onStateChanged,
  }) : super(key: key);

  @override
  _DragAndDropFillBlankState createState() => _DragAndDropFillBlankState();
}

class _DragAndDropFillBlankState extends State<DragAndDropFillBlank> {
  late Map<int, FillBlankWord?> _filledBlanks;
  late List<FillBlankWord> _remainingWords;
  late Map<String, FillBlankWord> _wordMap;

  @override
  void initState() {
    super.initState();
    _wordMap = {for (var w in widget.wordBank) w.id: w};
    _filledBlanks = {};
    for (int i = 0; i < widget.sentenceParts.length; i++) {
      if (widget.sentenceParts[i] == null) {
        _filledBlanks[i] = null;
      }
    }
    _remainingWords = List.from(widget.wordBank);
  }

  void _onWordDropped(int blankIndex, String wordId) {
    final newWord = _wordMap[wordId];
    if (newWord == null) return;

    setState(() {
      // Return existing word to pool if any
      final existing = _filledBlanks[blankIndex];
      if (existing != null) {
        _remainingWords.add(existing);
      }
      _remainingWords.removeWhere((w) => w.id == wordId);
      _filledBlanks[blankIndex] = newWord;
    });

    // Notify parent with current filled map
    final filledMap = Map<int, String>.fromEntries(
      _filledBlanks.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!.id))
    );
    widget.onStateChanged(filledMap);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildQuestionText(),
        SizedBox(height: 10,),
        _buildSentence(),
        const SizedBox(height: 24),
        _buildWordBank(),
      ],
    );
  }

  Widget _buildQuestionText() {
  final question = widget.question;
  if (question == null || question.isEmpty) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A5276).withOpacity(0.1),
          const Color(0xFF2E86C1).withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: const Color(0xFF2E86C1).withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon(
        //   Icons.,
        //   color: const Color(0xFF2E86C1),
        //   size: 24,
        // ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSentence() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.sentenceParts.asMap().entries.map((entry) {
        final index = entry.key;
        final part = entry.value;
        if (part != null) {
          return Text(part, style: const TextStyle(fontSize: 18));
        } else {
          final filledWord = _filledBlanks[index];
          return _buildBlankTarget(index, filledWord);
        }
      }).toList(),
    );
  }

  Widget _buildBlankTarget(int index, FillBlankWord? filledWord) {
    return DragTarget<String>(
      onWillAccept: (data) => true,
      onAccept: (wordId) => _onWordDropped(index, wordId),
      builder: (context, candidateData, rejectedData) {
        return Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: filledWord != null
              ? Text(filledWord.text, style: const TextStyle(fontSize: 16))
              : const Text(
                  '____',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildWordBank() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _remainingWords.map((word) {
        return Draggable<String>(
          data: word.id,
          feedback: Material(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Text(word.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          childWhenDragging: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(word.text, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(word.text, style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }
}