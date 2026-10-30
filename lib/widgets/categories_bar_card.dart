import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_stats.dart';
import 'charts/bar_chart.dart';

class CategoriesBarCard extends StatelessWidget {
  const CategoriesBarCard({super.key, required this.categories});

  final List<CategoryStat> categories;

  @override
  Widget build(BuildContext context) {
    final sorted = [...categories]
      ..sort((a, b) => (b.attempts).compareTo(a.attempts));
    final max = sorted.isEmpty ? 0 : sorted.first.attempts;

    final iconMap = {
      'history': Icons.history_edu,
      'food': Icons.restaurant,
      'sports': Icons.sports_soccer,
      'places': Icons.map,
      'language': Icons.translate,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categories', style: TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('No categories yet', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12))
          else
            ...sorted.map((item) {
              final icon = iconMap[item.category.toLowerCase()] ?? Icons.quiz;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AdminColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.category, style: AdminText.small),
                              Text(item.attempts.toString(), style: AdminText.caption),
                            ],
                          ),
                          const SizedBox(height: 6),
                          HBar(
                            value: item.attempts,
                            max: max == 0 ? 1 : max,
                            color: AdminColors.blue2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
