import 'package:flutter/material.dart';
import 'base_question_widget.dart';

class TrueFalseWidget extends BaseQuestionWidget {
  final int? selectedIndex;

  const TrueFalseWidget({
    Key? key,
    required super.questionData,
    required super.questionIndex,
    required super.onAnswer,
    required super.isAnswered,
     this.selectedIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildCategoryChip(),
        const SizedBox(height: 20),
        buildQuestionCard(questionData['question']),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(child: _buildButton(true, 'TRUE')),
            const SizedBox(width: 16),
            Expanded(child: _buildButton(false, 'FALSE')),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildButton(bool value, String label) {
    final bool isSelected = (value && selectedIndex == 0) || (!value && selectedIndex == 1);
    final int correctIndex = questionData['correct_answer_index'] ?? 0;
    final bool isCorrect = (value && correctIndex == 0) || (!value && correctIndex == 1);

    Color getBackgroundColor() {
      if (!isAnswered) {
        // Before submission: selected button blue, others neutral
        return isSelected ? Colors.blue : Colors.grey.shade300;
      } else {
        // After submission
        if (isSelected) {
          return isCorrect ? Colors.green : Colors.red;
        }
        // The other button may be light green if it's the correct one
        if (isCorrect) return Colors.green.shade100;
        return Colors.grey.shade300;
      }
    }

    Color getTextColor() {
      if (!isAnswered) {
        return isSelected ? Colors.white : Colors.black87;
      } else {
        if (isSelected) return Colors.white;
        if (isCorrect) return Colors.green.shade700;
        return Colors.black54;
      }
    }

    return InkWell(
      onTap: isAnswered ? null : () => onAnswer(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: getTextColor(),
            ),
          ),
        ),
      ),
    );
  }
}