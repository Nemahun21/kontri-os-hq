import 'package:flutter/material.dart';

import '../../../admin_theme.dart';
import '../../../models/admin_stats.dart';
import '../../../widgets/admin_card.dart';

class ActionNeededCard extends StatelessWidget {
  const ActionNeededCard({
    super.key,
    required this.queues,
    required this.onReportsTap,
    required this.onContribsTap,
  });

  final AdminQueues queues;
  final VoidCallback onReportsTap;
  final VoidCallback onContribsTap;

  @override
  Widget build(BuildContext context) {
    final hasReports = queues.reportsNew > 0;
    final hasContribs = queues.contribsNew > 0;

    if (!hasReports && !hasContribs) {
      return const SizedBox.shrink();
    }

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminCardLabel('ACTION NEEDED', color: AdminColors.red),
          if (hasReports) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: AdminColors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${queues.reportsNew} content reports need review', style: AdminText.body),
                      const SizedBox(height: 4),
                      Text('${queues.reportsWeek} this week', style: AdminText.small),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onReportsTap,
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.blue),
                  child: const Text('Review →'),
                ),
              ],
            ),
          ],
          if (hasReports && hasContribs) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
          ],
          if (hasContribs) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded, color: AdminColors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${queues.contribsNew} contributions waiting', style: AdminText.body),
                      const SizedBox(height: 4),
                      Text('${queues.contribsWeek} this week', style: AdminText.small),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onContribsTap,
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.blue),
                  child: const Text('Review →'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
