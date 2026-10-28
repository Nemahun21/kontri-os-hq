import 'package:flutter/material.dart';

import '../../../admin_theme.dart';
import '../../../models/admin_series.dart';
import '../../../models/admin_stats.dart';
import '../../../widgets/admin_card.dart';
import '../../../widgets/charts/sparkline.dart';
import '../../../widgets/delta_chip.dart';

class PulseStrip extends StatelessWidget {
  const PulseStrip({
    super.key,
    required this.stats,
    this.series,
    this.columns = 4,
    this.onDauTap,
    this.onNewTodayTap,
    this.onAttemptsTap,
    this.onTotalUsersTap,
  });

  final AdminPulse stats;
  final PulseSeries? series;
  final int columns;
  final VoidCallback? onDauTap;
  final VoidCallback? onNewTodayTap;
  final VoidCallback? onAttemptsTap;
  final VoidCallback? onTotalUsersTap;

  static double _mean(List<({DateTime day, int value})> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.fold<int>(0, (sum, item) => sum + item.value) / values.length;
  }

  static double _sum(List<({DateTime day, int value})> values) => values.fold<int>(0, (sum, item) => sum + item.value).toDouble();

  static double? _deltaCurrentVsPrevious(List<({DateTime day, int value})> currentValues) {
    if (currentValues.length < 2) {
      return null;
    }
    final current = currentValues.length > 7 ? currentValues.sublist(currentValues.length - 7) : currentValues;
    final prev = currentValues.length > 7 ? currentValues.sublist(0, currentValues.length - 7) : const <({DateTime day, int value})>[];
    if (prev.isEmpty) {
      return null;
    }
    final currentMean = _mean(current);
    final prevMean = _mean(prev);
    return currentMean - prevMean;
  }

  static double? _sumDelta(List<({DateTime day, int value})> values) {
    if (values.length < 2) {
      return null;
    }
    final current = values.length > 7 ? values.sublist(values.length - 7) : values;
    final prev = values.length > 7 ? values.sublist(0, values.length - 7) : const <({DateTime day, int value})>[];
    if (prev.isEmpty) {
      return null;
    }
    return _sum(current) - _sum(prev);
  }

  static double? _totalUsersDelta(int totalUsers, int newWeek) {
    if (totalUsers <= 0 || newWeek <= 0) {
      return null;
    }
    return ((newWeek / (totalUsers - newWeek)) * 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        label: 'DAU',
        value: stats.dau.toString(),
        secondaryText: 'WAU ${stats.wau}',
        delta: series != null ? _deltaCurrentVsPrevious(series!.dau) : null,
        color: AdminColors.green,
        sparkline: series != null ? series!.dau.map((entry) => entry.value).toList() : const <int>[],
        onTap: onDauTap,
      ),
      _KpiCard(
        label: 'New',
        value: stats.newToday.toString(),
        secondaryText: '${stats.newWeek} this week',
        delta: series != null ? _sumDelta(series!.signups) : null,
        color: AdminColors.blue2,
        sparkline: series != null ? series!.signups.map((entry) => entry.value).toList() : const <int>[],
        onTap: onNewTodayTap,
      ),
      _KpiCard(
        label: 'Attempts',
        value: stats.attemptsToday.toString(),
        secondaryText: '${stats.attemptsWeek} this wk',
        delta: series != null ? _sumDelta(series!.attempts) : null,
        color: AdminColors.amber,
        sparkline: series != null ? series!.attempts.map((entry) => entry.value).toList() : const <int>[],
        onTap: onAttemptsTap,
      ),
      _KpiCard(
        label: 'Total',
        value: stats.totalUsers.toString(),
        secondaryText: '+${stats.newWeek} this week',
        delta: _totalUsersDelta(stats.totalUsers, stats.newWeek),
        color: AdminColors.purple,
        sparkline: series != null ? series!.totalUsers.map((entry) => entry.value).toList() : const <int>[],
        onTap: onTotalUsersTap,
      ),
    ];

    if (columns == 2) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: card)))
          .toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.secondaryText,
    required this.delta,
    required this.color,
    required this.sparkline,
    this.onTap,
  });

  final String label;
  final String value;
  final String secondaryText;
  final double? delta;
  final Color color;
  final List<int> sparkline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spark = sparkline.isEmpty ? const <int>[] : sparkline;
    final card = AdminCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminCardLabel(label, color: color),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, size: 16, color: AdminColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondaryText,
            style: AdminText.small,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DeltaChip(pct: delta),
              const SizedBox(width: 8),
              Text('vs prev 7d', style: AdminText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Sparkline(
            values: spark.isEmpty ? const <num>[] : spark,
            color: color,
            width: 120,
            height: 30,
          ),
        ],
      ),
    );

    return card;
  }
}
