import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/category_questions_screen.dart';
import 'package:kohntri_os_hq/screens/admin/lesson_vocab_mangt_screen.dart';

class QuizCategorySelectionScreen extends StatelessWidget {
  final String parentCategory;
  final List<String> subCategories;

  const QuizCategorySelectionScreen({
    super.key,
    required this.parentCategory,
    required this.subCategories,
  });

  void _onViewContent(BuildContext context, String subCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryQuestionsScreen(category: subCategory),
      ),
    );
  }

  void _onLessons(BuildContext context, String subCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonVocabularyManagementScreen(
          contentType: 'adventure',
          category: subCategory,
          title: subCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(parentCategory),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildRow(context, subCategories[index]);
        },
      ),
    );
  }

  Widget _buildRow(BuildContext context, String subCategory) {
    final (IconData icon, Color color) = _styleFor(subCategory);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onViewContent(context, subCategory),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),

              // Title + hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subCategory,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage questions & lessons',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Lessons button (compact icon)
              _iconButton(
                icon: Icons.school_outlined,
                color: Colors.purple,
                tooltip: 'Lessons',
                onTap: () => _onLessons(context, subCategory),
              ),
              const SizedBox(width: 6),

              // View button (compact icon)
              _iconButton(
                icon: Icons.folder_open_outlined,
                color: color,
                tooltip: 'View',
                onTap: () => _onViewContent(context, subCategory),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _styleFor(String subCategory) {
    switch (subCategory) {
      case 'History':
        return (Icons.history_edu, Colors.brown);
      case 'Sports':
        return (Icons.sports_soccer, Colors.indigo);
      case 'Places':
        return (Icons.location_city, Colors.teal);
      case 'Food':
        return (Icons.restaurant, Colors.red);
      default:
        return (Icons.category, Colors.blue);
    }
  }
}