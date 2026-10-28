import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.name,
    required this.email,
    required this.showEmail,
    required this.onUsers,
    required this.onContent,
    required this.onRefresh,
    required this.onLogout,
    this.loading = false,
  });

  final String name;
  final String email;
  final bool showEmail;
  final VoidCallback onUsers;
  final VoidCallback onContent;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_search, color: AdminColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AdminText.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showEmail)
                  Text(
                    email,
                    style: AdminText.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onUsers,
                tooltip: 'Users',
                icon: const Icon(Icons.search, color: AdminColors.textPrimary),
              ),
              IconButton(
                onPressed: onContent,
                tooltip: 'Content',
                icon: const Icon(Icons.article_outlined, color: AdminColors.textPrimary),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Refresh',
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: AdminColors.textPrimary),
              ),
              IconButton(
                onPressed: onLogout,
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: AdminColors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
