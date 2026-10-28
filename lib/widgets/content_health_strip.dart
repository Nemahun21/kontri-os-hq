import 'package:flutter/material.dart';

import '../admin_theme.dart';

class ContentHealthStrip extends StatelessWidget {
  const ContentHealthStrip({
    super.key,
    required this.adventure,
    required this.language,
    required this.categories,
    required this.users,
  });

  final int adventure;
  final int language;
  final int categories;
  final int users;

  @override
  Widget build(BuildContext context) {
    final tiles = <_MiniTileData>[
      _MiniTileData(label: 'Adventure Q', value: adventure.toString(), color: AdminColors.blue),
      _MiniTileData(label: 'Language Q', value: language.toString(), color: AdminColors.blue2),
      _MiniTileData(label: 'Categories', value: categories.toString(), color: AdminColors.green),
      _MiniTileData(label: 'Users', value: users.toString(), color: AdminColors.purple),
    ];

    return Row(
      children: tiles.map((tile) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tile.label, style: AdminText.caption),
                const SizedBox(height: 6),
                Text(
                  tile.value,
                  style: TextStyle(
                    color: tile.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MiniTileData {
  const _MiniTileData({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;
}
