import 'package:flutter/material.dart';

import '../admin_theme.dart';

class ManageActionsRow extends StatelessWidget {
  const ManageActionsRow({
    super.key,
    required this.onHub,
    required this.onUsers,
    required this.onContent,
  });

  final VoidCallback onHub;
  final VoidCallback onUsers;
  final VoidCallback onContent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: onHub,
          icon: const Icon(Icons.dashboard_customize),
          label: const Text(''),
        ),
        OutlinedButton.icon(
          onPressed: onUsers,
          icon: const Icon(Icons.person_search),
          label: const Text('Manage users'),
        ),
        OutlinedButton.icon(
          onPressed: onContent,
          icon: const Icon(Icons.manage_search),
          label: const Text('Audit content'),
        ),
      ],
    );
  }
}
