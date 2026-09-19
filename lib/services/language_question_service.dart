import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/models/language_theme.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';

class LanguageQuestionService {
  final supabase = Supabase.instance.client;
  final _cache = CacheService();

  // ========== FETCH OPERATIONS (Cached) ==========

Future<List<LanguageQuestion>> getAllLanguageQuestions() async {
  const cacheKey = 'all_language_questions';
  final online = await ConnectivityHelper.isOnline();

  if (online) {
    try {
      final response = await supabase
          .from('language_questions')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));
      final questions = (response as List)
          .map((json) => LanguageQuestion.fromSupabase(json))
          .toList();
      await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
      return questions;
    } catch (_) {
      final cached = await _cache.getList<LanguageQuestion>(cacheKey, LanguageQuestion.fromSupabase);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  } else {
    final cached = await _cache.getList<LanguageQuestion>(cacheKey, LanguageQuestion.fromSupabase);
    return cached;
  }
}

  Future<Map<String, int>> getThemeCountsByLanguage() async {
  try {
    final response = await supabase
        .from('language_themes')
        .select('language_type_id, id')
        .timeout(const Duration(seconds: 5));

    final Map<String, int> counts = {};
    for (var item in response) {
      final langId = item['language_type_id'] as String;
      counts[langId] = (counts[langId] ?? 0) + 1;
    }
    return counts;
  } catch (_) {
    return {};
  }
}

  Future<int> getMaxPositionForTheme(String themeId) async {
    // This is a helper; not cached, but we can implement simple fallback
    final online = await ConnectivityHelper.isOnline();
    if (online) {
      try {
        final response = await supabase
            .from('language_questions')
            .select('position')
            .eq('theme_id', themeId)
            .order('position', ascending: false)
            .limit(1);
        if (response.isEmpty) return 0;
        return response.first['position'] as int;
      } catch (_) {
        // Fallback: count cached questions for this theme
        final cached = await _cache.getList<LanguageQuestion>('lang_questions_$themeId', LanguageQuestion.fromSupabase);
        if (cached.isNotEmpty) {
          return cached.map((q) => q.position).reduce((a, b) => a > b ? a : b) + 1;
        }
        return 0;
      }
    } else {
      final cached = await _cache.getList<LanguageQuestion>('lang_questions_$themeId', LanguageQuestion.fromSupabase);
      if (cached.isNotEmpty) {
        return cached.map((q) => q.position).reduce((a, b) => a > b ? a : b) + 1;
      }
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getLanguages() async {
    const cacheKey = 'languages_list';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase.from('language_type').select('id, name').order('name');
        final list = List<Map<String, dynamic>>.from(response);
        await _cache.set(cacheKey, list);
        return list;
      } catch (_) {
        final cached = await _cache.get(cacheKey);
        if (cached != null) return List<Map<String, dynamic>>.from(cached);
        rethrow;
      }
    } else {
      final cached = await _cache.get(cacheKey);
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      return [];
    }
  }

  Future<List<LanguageTheme>> getThemesForLanguage(String languageId) async {
    final cacheKey = 'themes_$languageId';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_themes')
            .select()
            .eq('language_type_id', languageId)
            .order('position');
        final themes = (response as List)
            .map((json) => LanguageTheme.fromSupabase(json))
            .toList();
        await _cache.set(cacheKey, themes.map((t) => t.toSupabase()).toList());
        return themes;
      } catch (_) {
        final cached = await _cache.getList<LanguageTheme>(cacheKey, LanguageTheme.fromSupabase);
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    } else {
      final cached = await _cache.getList<LanguageTheme>(cacheKey, LanguageTheme.fromSupabase);
      return cached;
    }
  }

  Future<LanguageTheme?> createTheme(String name, String languageId) async {
    // Write operation – we will try online, but also enqueue if offline? Actually this is called directly from admin screen.
    // The admin screen already handles pending operations. We'll just try to create online and return result.
    try {
      final response = await supabase
          .from('language_themes')
          .insert({'name': name, 'language_type_id': languageId})
          .select()
          .single();
      // Invalidate cache for this language's themes
      await _cache.set('themes_$languageId', null);
      return LanguageTheme.fromSupabase(response);
    } catch (e) {
      print('Error creating theme: $e');
      return null;
    }
  }

  Future<List<LanguageQuestion>> getQuestionsForTheme(String themeId) async {
    final cacheKey = 'lang_questions_$themeId';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_questions')
            .select()
            .eq('theme_id', themeId)
            .order('position');
        final questions = (response as List)
            .map((json) => LanguageQuestion.fromSupabase(json))
            .toList();
        await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
        return questions;
      } catch (_) {
        final cached = await _cache.getList<LanguageQuestion>(cacheKey, LanguageQuestion.fromSupabase);
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    } else {
      final cached = await _cache.getList<LanguageQuestion>(cacheKey, LanguageQuestion.fromSupabase);
      return cached;
    }
  }

  Future<Map<String, int>> getLanguageCounts() async {
    const cacheKey = 'language_counts';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_questions')
            .select('language_type_id');
        final languages = await supabase.from('language_type').select('id, name');
        final idToName = {for (var l in languages) l['id']: l['name']};
        final tempCounts = <String, int>{};
        for (var item in response) {
          final langId = item['language_type_id'] as String;
          tempCounts[langId] = (tempCounts[langId] ?? 0) + 1;
        }
        final counts = <String, int>{};
        tempCounts.forEach((id, count) {
          final name = idToName[id];
          if (name != null) counts[name] = count;
        });
        await _cache.set(cacheKey, counts);
        return counts;
      } catch (_) {
        final cached = await _cache.get(cacheKey);
        if (cached != null) return Map<String, int>.from(cached);
        rethrow;
      }
    } else {
      final cached = await _cache.get(cacheKey);
      if (cached != null) return Map<String, int>.from(cached);
      return {};
    }
  }

Future<int> getTotalLanguageQuestions() async {
  final counts = await getLanguageCounts();
  return counts.values.fold<int>(0, (sum, count) => sum + count);
}

  Future<String?> getLanguageIdByName(String name) async {
    final cacheKey = 'language_id_$name';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_type')
            .select('id')
            .eq('name', name)
            .maybeSingle();
        final id = response?['id'] as String?;
        if (id != null) {
          await _cache.set(cacheKey, id);
        }
        return id;
      } catch (_) {
        return await _cache.get(cacheKey) as String?;
      }
    } else {
      return await _cache.get(cacheKey) as String?;
    }
  }

  Future<String?> getThemeIdByNameAndLanguage(String themeName, String languageId) async {
    final cacheKey = 'theme_id_${languageId}_$themeName';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_themes')
            .select('id')
            .eq('name', themeName)
            .eq('language_type_id', languageId)
            .maybeSingle();
        final id = response?['id'] as String?;
        if (id != null) {
          await _cache.set(cacheKey, id);
        }
        return id;
      } catch (_) {
        return await _cache.get(cacheKey) as String?;
      }
    } else {
      return await _cache.get(cacheKey) as String?;
    }
  }

  // ========== WRITE OPERATIONS (with cache invalidation) ==========

  Future<void> addQuestion(LanguageQuestion question) async {
    final data = question.toSupabase()..remove('id');
    await supabase.from('language_questions').insert(data);
    // Invalidate caches
    await _cache.set('lang_questions_${question.themeId}', null);
    await _cache.set('language_counts', null);
  }

  Future<void> updateQuestion(LanguageQuestion question) async {
    await supabase
        .from('language_questions')
        .update(question.toSupabase())
        .eq('id', question.id);
    // Invalidate caches
    await _cache.set('lang_questions_${question.themeId}', null);
    await _cache.set('language_counts', null);
  }

  Future<void> deleteQuestion(String id) async {
    // First, get the themeId to invalidate cache
    String? themeId;
    try {
      final response = await supabase
          .from('language_questions')
          .select('theme_id')
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        themeId = response['theme_id'] as String?;
      }
    } catch (_) {}

    await supabase.from('language_questions').delete().eq('id', id);
    if (themeId != null) {
      await _cache.set('lang_questions_$themeId', null);
    }
    await _cache.set('language_counts', null);
  }

  Future<bool> deleteTheme(String themeId) async {
    try {
      await supabase.from('language_themes').delete().eq('id', themeId);
      // Invalidate caches
      await _cache.set('themes_$themeId', null);
      await _cache.set('lang_questions_$themeId', null);
      await _cache.set('language_counts', null);
      return true;
    } catch (e) {
      print('Error deleting theme: $e');
      return false;
    }
  }

  Future<LanguageTheme?> getTheme(String themeId) async {
    final cacheKey = 'theme_$themeId';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_themes')
            .select()
            .eq('id', themeId)
            .maybeSingle();
        if (response == null) return null;
        final theme = LanguageTheme.fromSupabase(response);
        await _cache.set(cacheKey, theme.toSupabase());
        return theme;
      } catch (_) {
        return await _cache.getTyped<LanguageTheme>(cacheKey, LanguageTheme.fromSupabase);
      }
    } else {
      return await _cache.getTyped<LanguageTheme>(cacheKey, LanguageTheme.fromSupabase);
    }
  }

  Future<bool> checkLanguageExists(String languageId) async {
    final cacheKey = 'lang_exists_$languageId';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('language_type')
            .select('id')
            .eq('id', languageId)
            .maybeSingle();
        final exists = response != null;
        await _cache.set(cacheKey, exists);
        return exists;
      } catch (_) {
        return await _cache.get(cacheKey) ?? false;
      }
    } else {
      return await _cache.get(cacheKey) ?? false;
    }
  }

// lib/services/language_question_service.dart
Future<void> addLanguage(String name, String code) async {
  // If online, insert directly
  final online = await ConnectivityHelper.isOnline();
  if (online) {
    await supabase.from('language_type').insert({'name': name, 'code': code});
    // Invalidate cache
    await _cache.set('languages_list', null);
  } else {
    // Offline: enqueue
    await PendingOperationService().enqueue(
      'language_type',
      'insert',
      {'name': name, 'code': code},
    );
    // Update cache locally (temporary ID not needed; cache will be updated on refresh)
    // We'll just add to cached list manually
    final cached = await _cache.get('languages_list');
    final list = cached != null ? List<Map<String, dynamic>>.from(cached) : [];
    list.add({'id': 'pending_${DateTime.now().millisecondsSinceEpoch}', 'name': name});
    await _cache.set('languages_list', list);
  }
}
// lib/services/language_question_service.dart

Future<void> deleteLanguage(String languageId) async {
  try {
    final trimmedId = languageId.trim();
    print('🔍 Attempting to delete language ID: "$trimmedId"');

    // Attempt delete
    final response = await supabase
        .from('language_type')
        .delete()
        .eq('id', trimmedId)
        .select();

    print('📦 Delete response: $response');

    if (response.isEmpty) {
      // Check if it still exists
      final check = await supabase
          .from('language_type')
          .select('id')
          .eq('id', trimmedId)
          .maybeSingle();
      if (check != null) {
        print('⚠️ Language still exists after delete.');
        throw Exception('Delete failed – language still exists.');
      } else {
        print('✅ Language already deleted (or never existed).');
      }
    } else {
      print('✅ Language deleted successfully.');
    }

    await _cache.set('languages_list', null);
    await _cache.set('language_counts', null);
  } catch (e) {
    print('❌ Delete error: $e');
    // If it's a PostgrestException, print the details
    if (e is PostgrestException) {
      print('PostgrestException details:');
      print('  Message: ${e.message}');
      print('  Code: ${e.code}');
      print('  Details: ${e.details}');
      print('  Hint: ${e.hint}');
    }
    // Do not attempt manual cascade; let the error bubble up
    rethrow;
  }
}

Future<Map<String, String>> getAllThemesMap() async {
  try {
    final response = await supabase
        .from('language_themes')
        .select('id, name')
        .timeout(const Duration(seconds: 5));
    final map = <String, String>{};
    for (var item in response) {
      map[item['id'] as String] = item['name'] as String;
    }
    return map;
  } catch (_) {
    return {};
  }
}
}