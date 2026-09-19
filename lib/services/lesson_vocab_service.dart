import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';

class LessonVocabularyService {
  final supabase = Supabase.instance.client;

 Future<List<LessonVocabulary>> getVocabulary({
  required String contentType,
  String? category,
  String? themeId,
  String? difficulty, // NEW
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
  // Admin methods
  Future<void> add(LessonVocabulary vocab) async {
    final data = vocab.toSupabase()..remove('id');
    await supabase.from('lesson_vocabulary').insert(data);
  }

  Future<void> update(LessonVocabulary vocab) async {
    await supabase.from('lesson_vocabulary').update(vocab.toSupabase()).eq('id', vocab.id);
  }

  Future<void> delete(String id) async {
    await supabase.from('lesson_vocabulary').delete().eq('id', id);
  }
}