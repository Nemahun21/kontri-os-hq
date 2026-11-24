import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';

class LessonVocabularyService {
  final supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // Read — pair-scoped (used by LessonCardScreen)
  // ─────────────────────────────────────────────
  Future<List<LessonVocabulary>> getVocabulary({
    required String contentType,
    String? category,
    String? themeId,
    String? difficulty,
  }) async {
    var query = supabase.from('lesson_vocabulary').select();

    if (contentType == 'adventure') {
      if (category != null) query = query.eq('category', category);
      if (difficulty != null) query = query.eq('difficulty', difficulty);
    } else {
      if (themeId != null) query = query.eq('theme_id', themeId);
    }

    final items = <LessonVocabulary>[];
    for (var offset = 0;; offset += 500) {
      final response = await query.order('position').order('id').range(offset, offset + 499);
      items.addAll((response as List).map((json) => LessonVocabulary.fromSupabase(json)));
      if (response.length < 500) break;
    }
    return items;
  }

  // ─────────────────────────────────────────────
  // Read — all entries (used by admin list)
  // ─────────────────────────────────────────────
  Future<List<LessonVocabulary>> getAllVocabulary() async {
    final response = await supabase
        .from('lesson_vocabulary')
        .select()
        .order('content_type', ascending: true)
        .order('category', ascending: true)
        .order('difficulty', ascending: true)
        .order('position', ascending: true);

    return (response as List)
        .map((json) => LessonVocabulary.fromSupabase(json))
        .toList();
  }

  // ─────────────────────────────────────────────
  // Write — admin CRUD
  // ─────────────────────────────────────────────
  /// Server validates every row and resolves existing Storage paths atomically.
  Future<void> commitImportRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty || rows.length > 25) throw ArgumentError('Batch must contain 1–25 records.');
    await supabase.rpc('commit_vocabulary_import', params: {'p_rows': rows});
  }

  Future<Map<String, dynamic>> checkFastDraft({
    required String themeId, required String term, required String definition,
    required String? slug, required List<String> paths,
  }) async {
    final response = await supabase.rpc('check_vocabulary_draft', params: {
      'p_theme': themeId, 'p_term': term, 'p_definition': definition,
      'p_slug': slug, 'p_paths': paths,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> add(LessonVocabulary vocab) async {
    // toSupabase() does not emit 'id', so insert lets Postgres generate it.
    await supabase.from('lesson_vocabulary').insert(vocab.toSupabase());
  }

  Future<void> update(LessonVocabulary vocab) async {
    await supabase
        .from('lesson_vocabulary')
        .update(vocab.toSupabase())
        .eq('id', vocab.id);
  }

  Future<void> delete(String id) async {
    await supabase.from('lesson_vocabulary').delete().eq('id', id);
  }
}