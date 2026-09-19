import 'package:flutter/material.dart';
import 'base_question_widget.dart';

class MultipleChoiceWidget extends BaseQuestionWidget {
  final int? selectedIndex;

  const MultipleChoiceWidget({
    Key? key,
    required super.questionData,
    required super.questionIndex,
    required super.onAnswer,
    required super.isAnswered,
    this.selectedIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final question = questionData['question'] as String? ?? '';
    print(
      'MultipleChoiceWidget build – isAnswered: $isAnswered, selectedIndex: $selectedIndex',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // buildCategoryChip(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            question,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 30),
        Expanded(
          child: ListView.builder(
            itemCount: questionData['options'].length,
            itemBuilder: (context, index) {
              return _buildOptionCard(
                option: questionData['options'][index],
                index: index,
                isCorrect: index == questionData['correct_answer_index'],
                isSelected: selectedIndex == index,
                letter: String.fromCharCode(65 + index),
              );
            },
          ),
        ),
      ],
    );
  }

Widget _buildOptionCard({
  required String option,
  required int index,
  required bool isCorrect,
  required bool isSelected,
  required String letter,
}) {
  Color backgroundColor = Colors.white;
  Color textColor = const Color(0xFF2C3E50);
  Color borderColor = Colors.grey[300]!;
  Color letterColor = const Color(0xFF2C3E50);

  if (isAnswered) {
    // After submission
    if (isCorrect) {
      backgroundColor = const Color(0xFF27AE60).withOpacity(0.1);
      borderColor = const Color(0xFF27AE60);
      letterColor = const Color(0xFF27AE60);
      textColor = const Color(0xFF27AE60);
    } else if (isSelected && !isCorrect) {
      backgroundColor = const Color(0xFFE74C3C).withOpacity(0.1);
      borderColor = const Color(0xFFE74C3C);
      letterColor = const Color(0xFFE74C3C);
      textColor = const Color(0xFFE74C3C);
    }
  } else {
    // Before submission – show blue highlight if selected
    if (isSelected) {
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue;
      textColor = Colors.blue;
      // letterColor stays as default for now; you can optionally set it to blue too
    }
  }

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAnswered ? null : () => onAnswer(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAnswered && isCorrect
                      ? const Color(0xFF27AE60)
                      : isAnswered && isSelected && !isCorrect
                      ? const Color(0xFFE74C3C)
                      : Colors.grey[100]!,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isAnswered && (isCorrect || (isSelected && !isCorrect))
                          ? Colors.white
                          : letterColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (isAnswered && isCorrect)
                const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 24),
              if (isAnswered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Color(0xFFE74C3C), size: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
}
