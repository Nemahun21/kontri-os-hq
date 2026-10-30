import 'package:flutter/material.dart';
// adjust imports to your theme/text styles
import '../../admin_theme.dart';

class ContentHealthStrip extends StatelessWidget {
  final int adventure;
  final int language;
  final int categories;
  final int users;

  final VoidCallback? onAdventureTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onCategoriesTap;
  final VoidCallback? onUsersTap;

  const ContentHealthStrip({
    super.key,
    required this.adventure,
    required this.language,
    required this.categories,
    required this.users,
    this.onAdventureTap,
    this.onLanguageTap,
    this.onCategoriesTap,
    this.onUsersTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Categories',
            value: categories,
            icon: Icons.category_outlined,
            onTap: onCategoriesTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Languages',
            value: language,
            icon: Icons.language,
            onTap: onLanguageTap,
          ),
        ),
        const SizedBox(width: 8),
        
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Users',
            value: users,
            icon: Icons.people_outline,
            onTap: onUsersTap,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: enabled ? AdminColors.blue : Colors.grey,
                  ),
                  const Spacer(),
                  if (enabled)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}