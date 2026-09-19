import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageChoiceWidget extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final Function(int) onAnswer;
  final bool isAnswered;
  final int? selectedIndex;

  const ImageChoiceWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.onAnswer,
    required this.isAnswered,
    this.selectedIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final question = questionData['question'] ?? '';
    final options = List<String>.from(questionData['options'] ?? []);
    final imageUrls = questionData['image_urls'] as Map<String, dynamic>? ?? {};
    final correctIndex = questionData['correct_answer_index'] ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            question,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
            children: List.generate(options.length, (index) {
              final isSelected = selectedIndex == index;
              final isCorrect = index == correctIndex;
              final imageUrl = imageUrls[index.toString()];

              // Determine border side based on answer state
              BorderSide borderSide;
              if (isAnswered) {
                borderSide = BorderSide(
                  color: isCorrect
                      ? Colors.green
                      : (isSelected ? Colors.red : Colors.grey.shade300),
                  width: 3,
                );
              } else {
                borderSide = BorderSide(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                );
              }

              return GestureDetector(
                onTap: isAnswered ? null : () => onAnswer(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(borderSide),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                )
                              : Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: isAnswered && isCorrect
                              ? Colors.green.shade50
                              : isAnswered && isSelected && !isCorrect
                                  ? Colors.red.shade50
                                  : Colors.grey.shade100,
                          child: Center(
                            child: Text(
                              options[index],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isAnswered && isCorrect
                                    ? Colors.green.shade700
                                    : isAnswered && isSelected && !isCorrect
                                        ? Colors.red.shade700
                                        : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}