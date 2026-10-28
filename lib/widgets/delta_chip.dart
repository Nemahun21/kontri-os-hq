import 'package:flutter/material.dart';

import '../admin_theme.dart';

class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, this.pct});

  final double? pct;

  @override
  Widget build(BuildContext context) {
    if (pct == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('—', style: TextStyle(color: AdminColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    }

    final positive = pct! >= 0;
    final value = pct!.abs().toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (positive ? AdminColors.green : AdminColors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : '-'}$value%',
        style: TextStyle(
          color: positive ? AdminColors.green : AdminColors.red,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
