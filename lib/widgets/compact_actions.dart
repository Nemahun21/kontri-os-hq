import 'package:flutter/material.dart';

class CompactActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final IconData editIcon;
  final Color editColor;
  final String editLabel;

  const CompactActions({
    super.key,
    this.onEdit,
    this.onDelete,
    this.editIcon = Icons.edit,
    this.editColor = Colors.blue,
    this.editLabel = 'Edit',
  });

  @override
  Widget build(BuildContext context) {
    // If there's only one action, show a single direct button — no menu
    if (onEdit != null && onDelete == null) {
      return _singleButton(editIcon, editColor, onEdit!);
    }
    if (onEdit == null && onDelete != null) {
      return _singleButton(Icons.delete, Colors.red, onDelete!);
    }

    // Both actions → popup menu with a single trigger icon
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: 'Options',
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (context) => [
          if (onEdit != null)
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(editIcon, size: 18, color: editColor),
                  const SizedBox(width: 8),
                  Text(editLabel),
                ],
              ),
            ),
          if (onDelete != null)
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _singleButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}