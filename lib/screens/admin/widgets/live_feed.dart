import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/user_lookup_screen.dart';

import '../../../admin_format.dart';
import '../../../admin_theme.dart';
import '../../../models/admin_stats.dart';
import '../../../widgets/admin_card.dart';

class LiveFeed extends StatelessWidget {
  const LiveFeed({super.key, required this.events});

  final List<ActivityEvent> events;

  static String _actionLabel(String eventType) {
    switch (eventType) {
      case 'quiz':
        return 'completed a quiz';
      case 'signin':
        return 'signed in';
      case 'signup':
      case 'sign_up':
        return 'signed up';
      default:
        return 'updated';
    }
  }

  static Color _dotColor(String eventType) {
    switch (eventType) {
      case 'quiz':
        return AdminColors.green;
      case 'signin':
        return AdminColors.blue2;
      default:
        return AdminColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = events.take(30).toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminCardLabel('LIVE ACTIVITY · LAST 2H', color: AdminColors.blue2),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const AdminEmptyState(text: 'No activity in the last 2 hours')
          else
            SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final event = visible[index];
                  final name = event.displayName ?? event.email;
                  final label = _actionLabel(event.event);
                  final color = _dotColor(event.event);

                  return InkWell(
                    onTap: event.email.isNotEmpty
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserLookupScreen(initialQuery: event.email),
                              ),
                            )
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    relTime(event.at),
                                    style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
