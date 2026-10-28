import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_series.dart';
import 'admin_card.dart';
import 'charts/line_chart.dart';

class TrendChartCard extends StatefulWidget {
  const TrendChartCard({super.key, this.series});

  final PulseSeries? series;

  @override
  State<TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<TrendChartCard> {
  int _range = 7;

  List<int> _valuesFor(List<({DateTime day, int value})> source, {required int range}) {
    if (source.isEmpty) {
      return const <int>[];
    }
    final slice = source.length > range ? source.sublist(source.length - range) : source;
    return slice.map((entry) => entry.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final hasData = series != null &&
        (series.dau.isNotEmpty || series.attempts.isNotEmpty || series.signups.isNotEmpty || series.totalUsers.isNotEmpty);

    final lineSeries = <LineSeries>[];
    if (series != null) {
      lineSeries.add(
        LineSeries(label: 'DAU', values: _valuesFor(series.dau, range: _range), color: AdminColors.green),
      );
      lineSeries.add(
        LineSeries(label: 'Attempts', values: _valuesFor(series.attempts, range: _range), color: AdminColors.amber),
      );
    }

    return AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Trend', style: TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7D')),
                    ButtonSegment(value: 30, label: Text('30D')),
                    ButtonSegment(value: 90, label: Text('90D')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (selection) {
                    setState(() => _range = selection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AdminColors.blue2.withValues(alpha: 0.12);
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AdminColors.blue2;
                      }
                      return AdminColors.textSecondary;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No data for this range', style: TextStyle(color: AdminColors.textSecondary))),
              )
            else ...[
              SizedBox(
                height: 180,
                child: LineChart(series: lineSeries, height: 180),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _LegendDot(color: AdminColors.green, label: 'DAU'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AdminColors.amber, label: 'Attempts'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AdminText.caption),
      ],
    );
  }
}
