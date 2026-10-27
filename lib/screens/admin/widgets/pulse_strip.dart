import 'package:flutter/material.dart';

import '../../../models/admin_stats.dart';

class PulseStrip extends StatelessWidget {
  final AdminPulse stats;

  const PulseStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        value: stats.dau.toString(),
        label: 'Active Today',
        color: Colors.green,
      ),
      _StatTile(
        value: stats.newToday.toString(),
        label: 'New Today',
        color: Colors.blue,
      ),
      _StatTile(
        value: stats.attemptsToday.toString(),
        label: 'Attempts Today',
        color: Colors.orange,
      ),
      _StatTile(
        value: stats.totalUsers.toString(),
        label: 'Total Users',
        color: Colors.grey,
      ),
    ];

    return SizedBox(
      height: 76,
      child: Row(
        children: List.generate(tiles.length, (index) {
          final tile = tiles[index];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
              child: tile,
            ),
          );
        }),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
