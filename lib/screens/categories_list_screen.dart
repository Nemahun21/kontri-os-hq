import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/content_search_screen.dart';
import 'category_detail_screen.dart';

class CategoriesListScreen extends StatelessWidget {
  final Map<String, int> categoryCounts;

  const CategoriesListScreen({super.key, required this.categoryCounts});

  @override
  Widget build(BuildContext context) {
    final names = categoryCounts.keys.toList()..sort();
    names.removeWhere((k) => k == 'Daily Challenge' || k == 'Languages');

    return Scaffold(
     appBar: AppBar(
  title: const Text('Categories'),
  actions: [
    IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Search all content',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContentSearchScreen()),
      ),
    ),
  ],
),
      body: names.isEmpty
          ? const Center(child: Text('No categories'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: names.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final name = names[i];
                final count = categoryCounts[name] ?? 0;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  title: Text(name),
                  subtitle: Text('$count questions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailScreen(category: name),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}