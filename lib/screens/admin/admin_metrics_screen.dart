import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/admin_stats_service.dart';

class AdminMetricsScreen extends StatefulWidget {
  final String metric;
  final String title;

  const AdminMetricsScreen({
    super.key,
    required this.metric,
    required this.title,
  });

  @override
  State<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends State<AdminMetricsScreen> {
  int _rangeDays = 30;
  List<({DateTime day, int value})> _data = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminStatsService.fetchTimeseries(widget.metric, days: _rangeDays);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  int _currentValue() {
    if (_data.isEmpty) return 0;
    return _data.last.value;
  }

  String _rangeLabel() {
    switch (widget.metric) {
      case 'dau':
        return 'active users';
      case 'signups':
        return 'new users';
      case 'attempts':
        return 'questions answered';
      case 'total_users':
        return 'total users';
      default:
        return 'metric';
    }
  }

  Widget _buildBarChart() {
    if (_data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxVal = _data.map((entry) => entry.value).reduce(math.max);
    if (maxVal <= 0) {
      return const Center(child: Text('No activity in this range'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in _data)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: math.max(2.0, (entry.value / maxVal) * 140),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E86C1),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComparisonCard() {
    if (_data.length < 2) {
      return const SizedBox.shrink();
    }

    final mid = (_data.length / 2).floor();
    final previous = _data.sublist(0, mid).fold<int>(0, (sum, entry) => sum + entry.value);
    final current = _data.sublist(mid).fold<int>(0, (sum, entry) => sum + entry.value);

    if (previous == 0) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('N/A', style: TextStyle(color: Colors.grey.shade700)),
        ),
      );
    }

    final delta = ((current - previous) / previous * 100).round();
    final positive = delta >= 0;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'vs previous $_rangeDays days',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  positive ? Icons.trending_up : Icons.trending_down,
                  color: positive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  '${positive ? '+' : ''}$delta%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: positive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF2C3E50))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentValue().toString(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rangeLabel(),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [7, 30, 90]
                        .map(
                          (range) => ChoiceChip(
                            label: Text('$range days'),
                            selected: _rangeDays == range,
                            onSelected: (_) {
                              setState(() => _rangeDays = range);
                              _load();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last 30 days',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: _buildBarChart(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonCard(),
                ],
              ),
            ),
    );
  }
}
