import 'package:flutter/material.dart';

import '../../../models/admin_stats.dart';

class PulseStrip extends StatelessWidget {
  final AdminPulse stats;
  final VoidCallback? onDauTap;
  final VoidCallback? onNewTodayTap;
  final VoidCallback? onAttemptsTap;
  final VoidCallback? onTotalUsersTap;

  const PulseStrip({
    super.key,
    required this.stats,
    this.onDauTap,
    this.onNewTodayTap,
    this.onAttemptsTap,
    this.onTotalUsersTap,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        value: stats.dau.toString(),
        label: 'Active Today',
        color: Colors.green,
        onTap: onDauTap,
      ),
      _StatTile(
        value: stats.newToday.toString(),
        label: 'New Today',
        color: Colors.blue,
        onTap: onNewTodayTap,
      ),
      _StatTile(
        value: stats.attemptsToday.toString(),
        label: 'Attempts Today',
        color: Colors.orange,
        onTap: onAttemptsTap,
      ),
      _StatTile(
        value: stats.totalUsers.toString(),
        label: 'Total Users',
        color: Colors.grey,
        onTap: onTotalUsersTap,
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
  final VoidCallback? onTap;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
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
      child: Stack(
        children: [
          Positioned(
            right: 4,
            top: 4,
            child: onTap != null
                ? const Icon(Icons.chevron_right, size: 14, color: Colors.grey)
                : const SizedBox.shrink(),
          ),
          Column(
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
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: child,
    );
  }
}
