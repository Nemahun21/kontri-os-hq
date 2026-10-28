import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/user_lookup_screen.dart';

import '../../../admin_theme.dart';
import '../../../models/admin_stats.dart';
import '../../../widgets/admin_card.dart';

class TopPlayersCard extends StatelessWidget {
  const TopPlayersCard({super.key, required this.players});

  final List<TopPlayer> players;

  @override
  Widget build(BuildContext context) {
    final list = players.take(5).toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminCardLabel('TOP PLAYERS', color: AdminColors.amber),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Center(child: Text('No players yet', style: TextStyle(color: AdminColors.textSecondary)))
          else
            ...list.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              final isTop = index == 0;
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserLookupScreen(initialQuery: player.displayName),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isTop ? AdminColors.amber.withValues(alpha: 0.14) : AdminColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isTop ? AdminColors.amber : AdminColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player.displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${player.totalScore}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, size: 14, color: AdminColors.amber),
                          const SizedBox(width: 2),
                          Text('${player.currentStreak}', style: AdminText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
