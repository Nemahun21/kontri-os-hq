import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DragAndDropWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final Function(Map<String, dynamic>) onAnswer;
  final bool isAnswered;
  final bool isCorrect;
  final String? droppedAnswer;

  const DragAndDropWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.onAnswer,
    required this.isAnswered,
    this.isCorrect = true,
    this.droppedAnswer,
  }) : super(key: key);

  @override
  _DragAndDropWidgetState createState() => _DragAndDropWidgetState();
}

class _DragAndDropWidgetState extends State<DragAndDropWidget> {
  int? _droppedIndex;

  @override
  Widget build(BuildContext context) {
    print(
      'DragAndDropWidget build - isAnswered: ${widget.isAnswered}, isCorrect: ${widget.isCorrect}',
    );
    final imageUrls =
        widget.questionData['image_urls'] as Map<String, dynamic>? ?? {};
    final correctIndex = widget.questionData['correct_answer_index'] ?? 0;
    final questionText = widget.questionData['question'] ?? 'Drag and drop';
    // Build a list of image URLs for indices 0..3 (if available)
    final List<String?> images = List.generate(
      imageUrls.length,
      (index) => imageUrls[index.toString()],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 1, 18, 10),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              questionText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Drop zone (fixed size, centered)
          Center(
            child: DragTarget<int>(
              onWillAccept: (data) => !widget.isAnswered,
              onAccept: (index) {
                print('Dropped index: $index');
                print('Correct index from question: $correctIndex');
                setState(() => _droppedIndex = index);
                //final isCorrect = index == correctIndex;
                widget.onAnswer({
                  'type': 'dragAndDrop',
                  //'answer': 'image_$index',
                  'droppedIndex': index,
                  // 'isCorrect': isCorrect,
                });
              },
              builder: (context, candidateData, rejectedData) {
                // If already answered, show final result (correct/incorrect)
                if (widget.isAnswered) {
                  final droppedImage = _droppedIndex != null
                      ? images[_droppedIndex!]
                      : null;
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: widget.isCorrect
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      border: Border.all(
                        color: widget.isCorrect ? Colors.green : Colors.red,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: droppedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: droppedImage,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.isCorrect ? '✓ Correct' : '✗ Wrong',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isCorrect
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                  );
                }

                // Before answer: show dropped image if any, otherwise placeholder
                final droppedImage = _droppedIndex != null
                    ? images[_droppedIndex!]
                    : null;
                if (droppedImage != null) {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: droppedImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                } else {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 30,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Drop here',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 15),

          // Grid of draggable images
          Expanded(
            child: GridView.count(
              //physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
              children: List.generate(imageUrls.length, (index) {
                final imageUrl = images[index];
                return Draggable<int>(
                  data: index,
                  feedback: Material(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.fill,
                                width: 100,
                                height: 100,
                              )
                            : Container(color: Colors.grey),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade300,
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Container(),
                    ),
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.fill,
                              width: 100,
                              height: 100,
                            )
                          : Container(color: Colors.grey),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
