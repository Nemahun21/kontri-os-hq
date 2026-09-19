import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  final String questionId;
  final Map<String, dynamic> questionData;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const QuestionCard({
    Key? key,
    required this.questionId,
    required this.questionData,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  Color _getTypeColor(String type) {
    switch (type) {
      case 'multipleChoice': return Colors.blue;
      case 'trueFalse': return Colors.green;
      case 'dragAndDrop': return Colors.orange;
      case 'textInput': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'multipleChoice': return Icons.radio_button_checked;
      case 'trueFalse': return Icons.thumb_up_alt;
      case 'dragAndDrop': return Icons.drag_indicator;
      case 'textInput': return Icons.keyboard;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = questionData['type'] ?? 'multipleChoice';
    final typeColor = _getTypeColor(type);
    final category = questionData['category'] ?? 'Uncategorized';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getTypeIcon(type), color: typeColor),
        ),
        title: Text(
          questionData['question'] ?? 'No question',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ID: ${questionId.substring(0, 6)}...',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onTap,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}