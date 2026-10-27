import 'package:flutter/material.dart';

import '../../../models/admin_stats.dart';

class ActionNeededCard extends StatelessWidget {
  final AdminQueues queues;
  final VoidCallback onReportsTap;
  final VoidCallback onContribsTap;

  const ActionNeededCard({
    super.key,
    required this.queues,
    required this.onReportsTap,
    required this.onContribsTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasReports = queues.reportsNew > 0;
    final hasContribs = queues.contribsNew > 0;

    if (!hasReports && !hasContribs) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasReports)
            _ActionRow(
              count: queues.reportsNew,
              subtitle: '${queues.reportsWeek} this week',
              title: 'content reports need review',
              color: Colors.red,
              onTap: onReportsTap,
              prefix: 'N ',
            ),
          if (hasReports && hasContribs)
            const Divider(height: 1),
          if (hasContribs)
            _ActionRow(
              count: queues.contribsNew,
              subtitle: '${queues.contribsWeek} this week',
              title: 'contributions waiting',
              color: Colors.amber,
              onTap: onContribsTap,
              prefix: 'N ',
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final int count;
  final String subtitle;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final String prefix;

  const _ActionRow({
    required this.count,
    required this.subtitle,
    required this.title,
    required this.color,
    required this.onTap,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final text = '$count $title';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.warning_amber_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2F36),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
