import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/category.dart';
import 'package:kohntri_os_hq/screens/audio_round_management_screen.dart';
import 'package:kohntri_os_hq/screens/daily_challenge_management_screen.dart';
import 'package:kohntri_os_hq/screens/languages_management_screen.dart';
import 'package:kohntri_os_hq/screens/quiz_category_selection_screen.dart';

class CategorySelectionScreen extends StatelessWidget {
  final List<Category> categories = [
    Category(name: 'Daily Challenge', icon: Icons.today, color: Colors.orange),
    Category(name: 'Quiz Category', icon: Icons.quiz, color: Colors.green),
    Category(name: 'Audio Round', icon: Icons.audiotrack, color: Colors.purple),

    Category(name: 'Languages', icon: Icons.language, color: Colors.red),
  ];

  CategorySelectionScreen({super.key});

  void _onCategoryTap(BuildContext context, Category category) {
    if (category.name == 'Daily Challenge') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DailyChallengeManagementScreen(),
        ),
      );
    } else if (category.name == 'Quiz Category') {
      // Navigate to sub‑category screen
      final subCategories = ['History', 'Sports', 'Places', 'Food'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizCategorySelectionScreen(
            parentCategory: category.name,
            subCategories: subCategories,
          ),
        ),
      );
    } else if (category.name == "Audio Round") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AudioRoundManagementScreen()),
      );
    } else if(category.name == "Languages"){
 Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LanguagesManagementScreen(),
        ),
      );
    }
    
    else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected ${category.name}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onCategoryTap(context, category),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 48, color: category.color),
              const SizedBox(height: 12),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
