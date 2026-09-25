import 'package:flutter/material.dart';

class MatchPairsWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final Function(Map<String, dynamic>) onAnswer;
  final bool isAnswered;

  const MatchPairsWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.onAnswer,
    required this.isAnswered,
  }) : super(key: key);

  @override
  _MatchPairsWidgetState createState() => _MatchPairsWidgetState();
}

class _MatchPairsWidgetState extends State<MatchPairsWidget> {
  late List<String> _leftItems;
  late List<_RightItem> _rightItems;
  late List<int?> _matches;
  late Map<int, int> _correctMatches;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    try {
      final typeData = widget.questionData['type_data'];
      if (typeData == null || typeData is! Map) {
        _errorMessage = 'Invalid question data';
        return;
      }

      final pairs = List<Map<String, dynamic>>.from(typeData['pairs'] ?? []);
      if (pairs.isEmpty) {
        _errorMessage = 'No pairs defined';
        return;
      }

      _leftItems = pairs.map((p) => p['left'] as String).toList();

      List<_RightItem> temp = [];
      for (int i = 0; i < pairs.length; i++) {
        temp.add(_RightItem(pairs[i]['right'] as String, i));
      }
      temp.shuffle();
      _rightItems = temp;

      final correctList = List<Map<String, dynamic>>.from(typeData['correctMatches'] ?? []);
      _correctMatches = {
        for (var item in correctList)
          item['leftIndex'] as int: item['rightIndex'] as int
      };

      _matches = List.filled(_leftItems.length, null);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error loading data';
    }
  }

  void _onWordDropped(int leftIndex, int originalRightIndex) {
    if (widget.isAnswered || _submitted) return;

    setState(() {
      final previousLeft = _matches.indexOf(originalRightIndex);
      if (previousLeft != -1) _matches[previousLeft] = null;
      _matches[leftIndex] = originalRightIndex;
    });

    // After state update, check if all matches are filled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_matches.every((m) => m != null) && !widget.isAnswered && !_submitted) {
        _submitAnswer();
      }
    });
  }

  void _submitAnswer() {
    if (_submitted) return;
    _submitted = true;
    final isCorrect = _isCorrect();
    widget.onAnswer({
      'type': 'matchPairs',
      'matches': _matches.map((m) => m!).toList(),
      'isCorrect': isCorrect,
    });
  }

  bool _isCorrect() {
    for (int i = 0; i < _matches.length; i++) {
      if (_matches[i] != _correctMatches[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    final questionText = widget.questionData['question'] ?? 'Match the pairs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            questionText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Drag the items on the right to match with the left.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              // Left column (drop targets)
              Expanded(
                child: ListView.builder(
                  itemCount: _leftItems.length,
                  itemBuilder: (context, index) {
                    return DragTarget<int>(
                      onWillAccept: (data) =>
                          !widget.isAnswered && !_submitted && _matches[index] == null,
                      onAccept: (originalRightIndex) => _onWordDropped(index, originalRightIndex),
                      builder: (context, candidateData, rejectedData) {
                        final matchedOriginalIndex = _matches[index];
                        String? matchedText;
                        if (matchedOriginalIndex != null) {
                          matchedText = _rightItems
                              .firstWhere(
                                (item) => item.originalIndex == matchedOriginalIndex,
                                orElse: () => _RightItem('', -1),
                              )
                              .text;
                        }

                        Color backgroundColor = Colors.blue.shade50;
                        Color borderColor = Colors.blue;
                        if (matchedOriginalIndex != null) {
                          backgroundColor = Colors.green.shade100;
                          borderColor = Colors.green;
                        }
                        if ((widget.isAnswered || _submitted) && matchedOriginalIndex != null) {
                          final isCorrect = _correctMatches[index] == matchedOriginalIndex;
                          backgroundColor = isCorrect ? Colors.green.shade100 : Colors.red.shade100;
                          borderColor = isCorrect ? Colors.green : Colors.red;
                        }

                        return Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_leftItems[index])),
                              if (matchedText != null)
                                Text(
                                  '→ $matchedText',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Right column (draggable items)
              Expanded(
                child: ListView.builder(
                  itemCount: _rightItems.length,
                  itemBuilder: (context, index) {
                    final rightItem = _rightItems[index];
                    final isMatched = _matches.contains(rightItem.originalIndex);
                    if (isMatched) return const SizedBox.shrink();

                    return Draggable<int>(
                      data: rightItem.originalIndex,
                      feedback: Material(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(blurRadius: 8)],
                          ),
                          child: Text(
                            rightItem.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      childWhenDragging: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rightItem.text),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rightItem.text),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (widget.isAnswered || _submitted)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isCorrect() ? '✓ Correct!' : '✗ Incorrect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isCorrect() ? Colors.green : Colors.red,
              ),
            ),
          ),
      ],
    );
  }
}

class _RightItem {
  final String text;
  final int originalIndex;
  _RightItem(this.text, this.originalIndex);
}