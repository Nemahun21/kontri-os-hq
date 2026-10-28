import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_series.dart';
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

  static Future<PulseSeries> fetchPulseSeries() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc(
          'admin_metrics_timeseries',
          params: {'metric': 'dau', 'days': 90},
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('Admin metrics fetchPulseSeries dau failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          return const <dynamic>[];
        }),
        Supabase.instance.client.rpc(
          'admin_metrics_timeseries',
          params: {'metric': 'attempts', 'days': 90},
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('Admin metrics fetchPulseSeries attempts failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          return const <dynamic>[];
        }),
        Supabase.instance.client.rpc(
          'admin_metrics_timeseries',
          params: {'metric': 'signups', 'days': 14},
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('Admin metrics fetchPulseSeries signups failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          return const <dynamic>[];
        }),
        Supabase.instance.client.rpc(
          'admin_metrics_timeseries',
          params: {'metric': 'total_users', 'days': 14},
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('Admin metrics fetchPulseSeries total_users failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          return const <dynamic>[];
        }),
      ]);

      return PulseSeries(
        dau: _parseTimeseries(results[0]),
        signups: _parseTimeseries(results[2]),
        attempts: _parseTimeseries(results[1]),
        totalUsers: _parseTimeseries(results[3]),
      );
    } catch (error, stackTrace) {
      debugPrint('Admin metrics fetchPulseSeries failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const PulseSeries();
    }
  }

  static List<({DateTime day, int value})> _parseTimeseries(dynamic response) {
    final rows = response is List ? response : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((entry) {
          final rawDay = entry['day'] ?? entry['date'];
          final value = entry['value'] is num ? (entry['value'] as num).toInt() : 0;
          final parsedDay = rawDay is String ? DateTime.tryParse(rawDay) : null;
          return (
            day: parsedDay ?? DateTime.now(),
            value: value,
          );
        })
        .toList();
  }
}
