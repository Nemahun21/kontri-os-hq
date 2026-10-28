import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_stats.dart';
import 'charts/donut_chart.dart';

class SignInDonutCard extends StatelessWidget {
  const SignInDonutCard({super.key, required this.signIn});

  final List<SignInStat> signIn;

  @override
  Widget build(BuildContext context) {
    final segments = <DonutSegment>[];
    for (final item in signIn) {
      final color = switch (item.provider.toLowerCase()) {
        'email' => AdminColors.blue,
        'google' => AdminColors.amber,
        _ => AdminColors.purple,
      };
      segments.add(DonutSegment(label: item.provider, value: item.n, color: color));
    }

    final total = signIn.fold<int>(0, (sum, item) => sum + item.n);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign-ins', style: TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              DonutChart(
                segments: segments,
                size: 96,
                centerLabel: total.toString(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((segment) {
                    final ratio = total == 0 ? 0 : (segment.value / total * 100);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: segment.color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${segment.label}: ${segment.value}',
                              style: AdminText.small,
                            ),
                          ),
                          Text(
                            '${ratio.toStringAsFixed(0)}%',
                            style: AdminText.caption,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
