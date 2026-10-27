import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/daily_content_management_screen.dart';
import 'package:kohntri_os_hq/screens/daily_challenge_management_screen.dart';
import 'package:kohntri_os_hq/services/daily_content_service.dart';

class DailyContentOverview extends StatelessWidget {
  const DailyContentOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DailyItem(
        title: 'Daily Challenge',
        subtitle: 'Questions',
        icon: Icons.quiz_outlined,
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyChallengeManagementScreen(),
          ),
        ),
      ),
      _DailyItem(
        title: 'Proverbs',
        subtitle: 'Wisdom and sayings',
        icon: Icons.format_quote_outlined,
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyContentManagementScreen(
              contentType: ContentType.proverb,
            ),
          ),
        ),
      ),
      _DailyItem(
        title: 'Interesting Facts',
        subtitle: 'Interesting cultural facts',
        icon: Icons.lightbulb_outline,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyContentManagementScreen(
              contentType: ContentType.funFact,
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Daily Content'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Content that rotates daily',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),

          // Rows
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRow(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_DailyItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// Helper class
// =====================================================
class _DailyItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _DailyItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}