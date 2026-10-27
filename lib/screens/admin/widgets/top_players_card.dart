import 'package:flutter/material.dart';

import '../../../models/admin_stats.dart';

class TopPlayersCard extends StatelessWidget {
  final List<TopPlayer> players;

  const TopPlayersCard({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    final list = players.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No players yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(list.length, (index) {
                    final player = list[index];
                    final rank = index + 1;
                    final isTop = rank == 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isTop ? Colors.amber.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isTop ? Colors.amber.shade300 : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isTop ? Colors.amber.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              player.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${player.totalScore}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text(
                                '${player.currentStreak}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ),
    );
  }
}
