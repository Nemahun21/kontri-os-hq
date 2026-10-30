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

    final response = await query.order('position');
    return (response as List)
        .map((json) => LessonVocabulary.fromSupabase(json))
        .toList();
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