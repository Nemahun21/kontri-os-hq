import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/models/language_theme.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';

class QuestionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CacheService _cache = CacheService();
  final String _tableName = 'questions';

  // ========== FETCH OPERATIONS (with timeout + cache fallback) ==========

  Future<Map<Difficulty, int>> getQuestionCountsByDifficulty(String category) async {
    final cacheKey = 'difficulty_counts_$category';
    try {
      final response = await _supabase
          .from(_tableName)
          .select('difficulty')
          .eq('category', category)
          .timeout(const Duration(seconds: 5));

      final counts = <Difficulty, int>{};
      for (var item in response) {
        final diff = Difficulty.values.firstWhere(
          (e) => e.name == item['difficulty'],
          orElse: () => Difficulty.medium,
        );
        counts[diff] = (counts[diff] ?? 0) + 1;
      }
      final cacheData = counts.map((k, v) => MapEntry(k.name, v));
      await _cache.set(cacheKey, cacheData);
      return counts;
    } catch (_) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) {
        final map = Map<String, int>.from(cached);
        return map.map((key, value) => MapEntry(
          Difficulty.values.firstWhere((d) => d.name == key),
          value,
        ));
      }
      rethrow;
    }
  }

  Future<List<Question>> getAllQuestions() async {
    const cacheKey = 'all_questions';
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      final questions = (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
      await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
      return questions;
    } catch (_) {
      final cached = await _cache.getList<Question>(cacheKey, Question.fromSupabase);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Question>> getQuestionsByCategory(String category) async {
    final cacheKey = 'questions_category_$category';
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('category', category)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      final questions = (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
      await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
      return questions;
    } catch (_) {
      final cached = await _cache.getList<Question>(cacheKey, Question.fromSupabase);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Question>> getRandomQuestions(int count, {String? category}) async {
    try {
      var query = _supabase.from(_tableName).select();
      if (category != null) {
        query = query.eq('category', category);
      }
      final response = await query.timeout(const Duration(seconds: 5));
      final allQuestions = (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
      allQuestions.shuffle();
      return allQuestions.take(count).toList();
    } catch (_) {
      final all = await getAllQuestions();
      all.shuffle();
      return all.take(count).toList();
    }
  }

  Future<Question?> getQuestionById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .single()
          .timeout(const Duration(seconds: 5));
      return Question.fromSupabase(response);
    } catch (_) {
      final all = await getAllQuestions();
      for (var q in all) {
        if (q.id == id) return q;
      }
      return null;
    }
  }

  // ========== ADMIN OPERATIONS (no caching, but invalidates caches) ==========

  Future<bool> addQuestion(Question question) async {
    try {
      await _supabase.from(_tableName).insert(question.toSupabase());
      print('✅ Question added successfully');
      await _cache.set('all_questions', null);
      await _cache.set('questions_category_${question.category}', null);
      await _cache.set('category_counts', null);
      return true;
    } catch (e) {
      print('❌ Error adding question: $e');
      return false;
    }
  }

  Future<bool> addQuestions(List<Question> questions) async {
    try {
      final data = questions.map((q) => q.toSupabase()).toList();
      await _supabase.from(_tableName).insert(data);
      print('✅ ${questions.length} questions added');
      await _cache.set('all_questions', null);
      for (var cat in questions.map((q) => q.category).toSet()) {
        await _cache.set('questions_category_$cat', null);
      }
      await _cache.set('category_counts', null);
      return true;
    } catch (e) {
      print('❌ Error adding questions: $e');
      return false;
    }
  }

  Future<bool> updateQuestion(Question question) async {
    try {
      await _supabase
          .from(_tableName)
          .update(question.toSupabase())
          .eq('id', question.id);
      print('✅ Question updated');
      await _cache.set('all_questions', null);
      await _cache.set('questions_category_${question.category}', null);
      await _cache.set('category_counts', null);
      return true;
    } catch (e) {
      print('❌ Error updating question: $e');
      return false;
    }
  }

  Future<bool> deleteQuestion(String id) async {
    try {
      final q = await getQuestionById(id);
      await _supabase.from(_tableName).delete().eq('id', id);
      print('✅ Question deleted');
      if (q != null) {
        await _cache.set('questions_category_${q.category}', null);
      }
      await _cache.set('all_questions', null);
      await _cache.set('category_counts', null);
      return true;
    } catch (e) {
      print('❌ Error deleting question: $e');
      return false;
    }
  }

  // ========== UTILITY OPERATIONS ==========

  Future<Map<String, int>> getQuestionCountByCategory() async {
    const cacheKey = 'category_counts';
    try {
      final response = await _supabase
          .from(_tableName)
          .select('category')
          .timeout(const Duration(seconds: 5));

      final counts = <String, int>{};
      for (var item in response) {
        final cat = item['category'] as String;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      await _cache.set(cacheKey, counts);
      return counts;
    } catch (_) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) return Map<String, int>.from(cached);
      rethrow;
    }
  }

  Future<List<String>> getAllCategories() async {
    final counts = await getQuestionCountByCategory();
    return counts.keys.toList();
  }

  Future<List<Question>> searchQuestions(String query) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .ilike('question', '%$query%')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));
      return (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
    } catch (_) {
      final all = await getAllQuestions();
      return all.where((q) => q.question.toLowerCase().contains(query.toLowerCase())).toList();
    }
  }

  // ========== LANGUAGE‑RELATED METHODS ==========

  Future<Map<String, int>> getLanguageCounts() async {
    const cacheKey = 'language_counts';
    try {
      final response = await _supabase
          .from('questions')
          .select('language')
          .eq('category', 'Languages')
          .timeout(const Duration(seconds: 5));

      final counts = <String, int>{};
      for (var item in response) {
        final lang = item['language'] as String?;
        if (lang != null) {
          counts[lang] = (counts[lang] ?? 0) + 1;
        }
      }
      await _cache.set(cacheKey, counts);
      return counts;
    } catch (_) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) return Map<String, int>.from(cached);
      rethrow;
    }
  }

  Future<String?> getLanguageIdByName(String name) async {
    final cacheKey = 'language_id_$name';
    try {
      final response = await _supabase
          .from('language_type')
          .select('id')
          .eq('name', name.trim())
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final id = response?['id'] as String?;
      if (id != null) await _cache.set(cacheKey, id);
      return id;
    } catch (_) {
      return await _cache.get(cacheKey) as String?;
    }
  }

  Future<List<Question>> getQuestionsByLanguage(String language) async {
    final cacheKey = 'questions_language_$language';
    try {
      final response = await _supabase
          .from('questions')
          .select()
          .eq('category', 'Languages')
          .eq('language', language)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      final questions = (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
      await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
      return questions;
    } catch (_) {
      final cached = await _cache.getList<Question>(cacheKey, Question.fromSupabase);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<LanguageTheme>> getThemesForLanguage(String languageId) async {
    final cacheKey = 'themes_$languageId';
    try {
      final response = await _supabase
          .from('language_themes')
          .select()
          .eq('language_id', languageId)
          .order('name')
          .timeout(const Duration(seconds: 5));

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
  }

  Future<List<Question>> getQuestionsByTheme(String themeId) async {
    final cacheKey = 'questions_theme_$themeId';
    try {
      final response = await _supabase
          .from('questions')
          .select()
          .eq('theme_id', themeId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      final questions = (response as List)
          .map((q) => Question.fromSupabase(q))
          .toList();
      await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
      return questions;
    } catch (_) {
      final cached = await _cache.getList<Question>(cacheKey, Question.fromSupabase);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLanguages() async {
    const cacheKey = 'languages_list';
    try {
      final response = await _supabase
          .from('language_type')
          .select('id, name')
          .order('name')
          .timeout(const Duration(seconds: 5));

      final list = List<Map<String, dynamic>>.from(response);
      await _cache.set(cacheKey, list);
      return list;
    } catch (_) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      rethrow;
    }
  }
}