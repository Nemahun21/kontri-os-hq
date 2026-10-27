import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_stats.dart';

class AdminStatsService {
  const AdminStatsService._();

  static Future<AdminStats> fetch() async {
    try {
      final response = await Supabase.instance.client.rpc('admin_command_centre');
      final map = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      return AdminStats.fromJson(map);
    } catch (error, stackTrace) {
      debugPrint('Admin command centre fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<List<({DateTime day, int value})>> fetchTimeseries(
    String metric, {
    int days = 30,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'admin_metrics_timeseries',
        params: {'metric': metric, 'days': days},
      );

      final rows = response is List ? response : const <dynamic>[];
      return rows
          .whereType<Map>()
          .map((entry) {
            final value = entry['value'] is num ? (entry['value'] as num).toInt() : 0;
            final rawDay = entry['day'] ?? entry['date'];
            final parsed = rawDay is String ? DateTime.tryParse(rawDay) : null;
            return (
              day: parsed ?? DateTime.now(),
              value: value,
            );
          })
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Admin metrics fetchTimeseries failed for $metric: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <({DateTime day, int value})>[];
    }
  }
}
