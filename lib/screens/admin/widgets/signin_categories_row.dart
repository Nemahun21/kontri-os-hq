import 'package:flutter/material.dart';

import '../../../models/admin_stats.dart';

class SignInCategoriesRow extends StatelessWidget {
  final List<SignInStat> signIn;
  final List<CategoryStat> categories;

  const SignInCategoriesRow({
    super.key,
    required this.signIn,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              title: 'Sign-ins',
              emptyText: 'No data yet',
              rows: signIn.isEmpty
                  ? const <Widget>[]
                  : signIn
                      .map(
                        (item) => Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.provider == 'google'
                                    ? Colors.redAccent
                                    : Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.provider,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              item.n.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoCard(
              title: 'Played today',
              emptyText: 'No data yet',
              rows: categories.isEmpty
                  ? const <Widget>[]
                  : categories
                      .map(
                        (item) => Row(
                          children: [
                            Icon(
                              _categoryIcon(item.category),
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              item.attempts.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'history':
        return Icons.history_edu;
      case 'food':
        return Icons.restaurant;
      case 'sports':
        return Icons.sports_soccer;
      case 'places':
        return Icons.map;
      case 'language':
        return Icons.translate;
      default:
        return Icons.quiz;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> rows;

  const _InfoCard({
    required this.title,
    required this.emptyText,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2F36),
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyText,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}
