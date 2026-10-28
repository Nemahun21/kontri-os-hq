import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_lookup.dart';

class AdminLookupService {
  const AdminLookupService._();

  static Future<List<AdminUserSummary>> searchUsers(String q, {int lim = 30}) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'admin_search_users',
        params: {'q': q, 'lim': lim},
      );
      final rows = response is List ? response : const <dynamic>[];
      return rows
          .whereType<Map>()
          .map((entry) => AdminUserSummary.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Admin lookup searchUsers failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<AdminUserDetail?> userDetail(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'admin_user_detail',
        params: {'target_id': userId},
      );
      if (response is! Map) {
        return null;
      }
      return AdminUserDetail.fromJson(Map<String, dynamic>.from(response));
    } catch (error, stackTrace) {
      debugPrint('Admin lookup userDetail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<List<AdminContentSummary>> searchContent(String q, {int lim = 30}) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'admin_search_content',
        params: {'q': q, 'lim': lim},
      );
      final rows = response is List ? response : const <dynamic>[];
      return rows
          .whereType<Map>()
          .map((entry) => AdminContentSummary.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Admin lookup searchContent failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<AdminContentDetail?> contentDetail(String contentId, String kind) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'admin_content_detail',
        params: {'target_id': contentId, 'kind': kind},
      );
      if (response is! Map) {
        return null;
      }
      return AdminContentDetail.fromJson(Map<String, dynamic>.from(response));
    } catch (error, stackTrace) {
      debugPrint('Admin lookup contentDetail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<bool> banUser(String userId, String reason) async {
    try {
      await Supabase.instance.client.rpc(
        'ban_user',
        params: {'target_id': userId},
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Admin lookup banUser failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> unbanUser(String userId) async {
    try {
      await Supabase.instance.client.rpc(
        'unban_user',
        params: {'target_id': userId},
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Admin lookup unbanUser failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> demoteUser(String userId) async {
    try {
      await Supabase.instance.client.rpc(
        'demote_user',
        params: {'target_id': userId},
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Admin lookup demoteUser failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> sendPasswordReset(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Admin lookup sendPasswordReset failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
