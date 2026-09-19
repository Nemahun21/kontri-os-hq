import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';

enum ContentType { proverb, funFact, challenge }

class DailyContentService {
  final supabase = Supabase.instance.client;
  final _cache = CacheService();

  // ===================== USER‑SIDE METHODS =====================

  /// Fetch today's content (cached) – used by the user app
  Future<Map<String, dynamic>> getTodayContent({bool forceRefresh = false}) async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final cacheKey = 'daily_content_$today';

    if (!forceRefresh) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) {
        try {
          final decoded = Map<String, dynamic>.from(cached);
          if (decoded['date'] == today) return decoded;
        } catch (_) {}
      }
    }

    final result = await _fetchFromSupabase(today);
    await _cache.set(cacheKey, result);
    return result;
  }

  /// Extract challenge questions (if today is a challenge)
  Future<List<Map<String, dynamic>>> getDailyQuestions() async {
    final content = await getTodayContent();
    if (content['active_type'] == 'challenge') {
      final data = content['content'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map<String, dynamic>) return [data];
    }
    return [];
  }

  // Internal fetch (user)
  Future<Map<String, dynamic>> _fetchFromSupabase(String today) async {
    final settings = await supabase
        .from('daily_content_settings')
        .select('active_type, active_title')
        .eq('id', 1)
        .maybeSingle();

    if (settings == null) throw Exception('No daily content settings');

    final type = settings['active_type'] as String;
    final title = settings['active_title'] as String? ?? '';

    Map<String, dynamic> result = {
      'date': today,
      'active_type': type,
      'active_title': title,
    };

    dynamic raw;
    if (type == 'challenge') {
      raw = await supabase
          .from('daily_challenge_active')
          .select('''
            date,
            position,
            question_id,
            daily_challenge_questions(*)
          ''')
          .eq('date', today)
          .maybeSingle();
      if (raw != null) {
        result['content'] = raw['daily_challenge_questions'];
        result['position'] = raw['position'];
        result['question_id'] = raw['question_id'];
      }
    } else if (type == 'proverb') {
      raw = await supabase
          .from('daily_proverbs_active')
          .select('''
            date,
            proverb_id,
            daily_proverbs(*)
          ''')
          .eq('date', today)
          .maybeSingle();
      if (raw != null) {
        result['content'] = raw['daily_proverbs'];
        result['proverb_id'] = raw['proverb_id'];
      }
    } else if (type == 'fun_fact') {
      raw = await supabase
          .from('daily_funfacts_active')
          .select('''
            date,
            funfact_id,
            daily_funfacts(*)
          ''')
          .eq('date', today)
          .maybeSingle();
      if (raw != null) {
        result['content'] = raw['daily_funfacts'];
        result['funfact_id'] = raw['funfact_id'];
      }
    } else {
      throw Exception('Unknown active type: $type');
    }

    result['raw'] = raw;
    if (raw == null) throw Exception('No active content for $type on $today');
    return result;
  }

  // ===================== ADMIN‑SIDE METHODS =====================

  String _tableName(ContentType type) {
    switch (type) {
      case ContentType.proverb:
        return 'daily_proverbs';
      case ContentType.funFact:
        return 'daily_funfacts';
      case ContentType.challenge:
        return 'daily_challenge_questions';
    }
  }
  // Add this public method
String tableNameForType(ContentType type) => _tableName(type);

 Future<List<Map<String, dynamic>>> getAll(ContentType type) async {
  final cacheKey = 'admin_${_tableName(type)}';
  final online = await ConnectivityHelper.isOnline();

  if (online) {
    try {
      final response = await supabase
          .from(_tableName(type))
          .select()
          .order('position', ascending: true);
      final list = List<Map<String, dynamic>>.from(response);
      await _cache.set(cacheKey, list);
      return list;
    } catch (_) {
      // Fallback to cache if online fetch fails
      final cached = await _cache.get(cacheKey);
      if (cached != null) {
        try {
          return List<Map<String, dynamic>>.from(cached);
        } catch (_) {
          // cached data is not a list – ignore
        }
      }
      rethrow;
    }
  } else {
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      try {
        return List<Map<String, dynamic>>.from(cached);
      } catch (_) {
        // cached data is not a list – return empty
      }
    }
    return [];
  }
}

  Future<Map<String, dynamic>> getOne(ContentType type, String id) async {
    final response = await supabase
        .from(_tableName(type))
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) throw Exception('Not found');
    return response;
  }

  // ----- WRITE (invalidate cache) -----
  Future<void> create(ContentType type, Map<String, dynamic> data) async {
    data.remove('id');
    await supabase.from(_tableName(type)).insert(data);
    await _cache.set('admin_${_tableName(type)}', null);
  }

  Future<void> update(ContentType type, String id, Map<String, dynamic> data) async {
    data.remove('id');
    await supabase.from(_tableName(type)).update(data).eq('id', id);
    await _cache.set('admin_${_tableName(type)}', null);
  }

  Future<void> delete(ContentType type, String id) async {
    await supabase.from(_tableName(type)).delete().eq('id', id);
    await _cache.set('admin_${_tableName(type)}', null);
  }

  // ----- Convenience getters (admin) -----
  Future<List<Map<String, dynamic>>> getProverbs() => getAll(ContentType.proverb);
  Future<List<Map<String, dynamic>>> getFunFacts() => getAll(ContentType.funFact);
  Future<List<Map<String, dynamic>>> getChallenges() => getAll(ContentType.challenge);
}