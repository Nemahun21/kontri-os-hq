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
}
