import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';

class LessonVocabularyService {
  final supabase = Supabase.instance.client;
  static const draftBucket = 'vocabulary_assets_v2';

  Future<List<Map<String,dynamic>>> _read(String table, {
    String? contentType, String? category, String? themeId, String? difficulty,
  }) async {
    final rows = <Map<String,dynamic>>[];
    for (var offset=0;;offset+=200) {
      var q = supabase.from(table).select();
      if(contentType != null) q=q.eq('content_type',contentType);
      if(category != null) q=q.eq('category',category);
      if(themeId != null) q=q.eq('theme_id',themeId);
      if(difficulty != null) q=q.eq('difficulty',difficulty);
      final page=await q.order('id').range(offset,offset+199);
      rows.addAll(List<Map<String,dynamic>>.from(page));
      if(page.length<200) break;
    }
    return rows;
  }

  Future<List<LessonVocabulary>> getVocabulary({
    required String contentType, String? category, String? themeId,
    String? difficulty,
  }) => _merged(contentType:contentType,category:category,themeId:themeId,difficulty:difficulty);

  Future<List<LessonVocabulary>> getAllVocabulary() => _merged();

  Future<List<LessonVocabulary>> _merged({
    String? contentType, String? category, String? themeId, String? difficulty,
  }) async {
    final base=await _read('lesson_vocabulary',contentType:contentType,category:category,themeId:themeId);
    final revisions=contentType=='adventure' ? <Map<String,dynamic>>[] :
      await _read('lesson_vocabulary_revisions',contentType:'language',themeId:themeId);
    final byId=<String,Map<String,dynamic>>{for(final row in base) row['id'].toString():row};
    for(final row in revisions) {
      if(row['status']!='published') byId[row['id'].toString()]=row;
    }
    final entries=byId.values.map(LessonVocabulary.fromSupabase)
      .where((v)=>difficulty==null || v.difficulty==difficulty).toList();
    entries.sort((a,b) {final c=a.position.compareTo(b.position);return c==0?a.id.compareTo(b.id):c;});
    return entries;
  }

  Future<void> add(LessonVocabulary vocab) async {
    await _save(vocab);
  }
  Future<void> update(LessonVocabulary vocab) async {
    await _save(vocab);
  }
  Future<void> _save(LessonVocabulary vocab) async {
    if(vocab.contentType!='language') throw StateError('Adventure editing is outside this preview mission.');
    await supabase.rpc('v2_save_vocab_draft',params:{'p_row':{
      ...vocab.toSupabase(),
      if(vocab.reviewNote != null) 'review_note':vocab.reviewNote!.trim(),
      if(vocab.id.isNotEmpty) 'id':vocab.id,
    }});
  }
  Future<void> delete(String id) async {
    final removed=await supabase.rpc('v2_discard_vocab_draft',params:{'p_id':id});
    if(removed!=true) throw StateError('Only draft or pending revisions can be discarded.');
  }
  Future<int> submitTheme(String theme) async =>
      (await supabase.rpc('v2_submit_vocab_theme',params:{'p_theme':theme}) as num).toInt();
  Future<int> publishTheme(String theme) async =>
      (await supabase.rpc('v2_publish_vocab_theme',params:{'p_theme':theme}) as num).toInt();
  Future<bool> canPublish() async => await supabase.rpc('is_super_admin') == true;

  /// Local uploads never overwrite an existing object. Reuse only identical bytes.
  Future<String> uploadAsset({required LessonVocabulary item, required String filename,
      required Uint8List bytes, required bool audio}) async {
    final slug=item.fileSlug;
    if(slug==null || slug.isEmpty) throw StateError('Save the draft before attaching media.');
    final name=filename.toLowerCase();
    final language=slug.split('_').first;
    final expected=audio ? RegExp('^'+slug+r'(?:_v[0-9a-f]{16})?\.mp3$')
      : RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*\.(png|jpg|jpeg|webp)$');
    if(!expected.hasMatch(name)) throw FormatException(audio?'MP3 must match the vocabulary file slug.':'Use a lowercase shared image concept filename.');
    if(bytes.length<12 || bytes.length>(audio?10:5)*1024*1024) throw const FormatException('Invalid file size.');
    final mime=audio?'audio/mpeg':name.endsWith('.png')?'image/png':name.endsWith('.webp')?'image/webp':'image/jpeg';
    final valid=audio ? ((bytes[0]==73&&bytes[1]==68&&bytes[2]==51)||(bytes[0]==255&&(bytes[1]&224)==224))
      : mime=='image/png'?listEquals(bytes.sublist(0,8),[137,80,78,71,13,10,26,10])
      : mime=='image/webp'?String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&String.fromCharCodes(bytes.sublist(8,12))=='WEBP'
      : bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    if(!valid) throw const FormatException('File signature does not match its format.');
    final path=audio?'audio/$language/$name':'images/$name';
    final store=supabase.storage.from(draftBucket);
    try {await store.uploadBinary(path,bytes,fileOptions:FileOptions(contentType:mime,upsert:false));}
    on StorageException catch (e) {
      if(e.statusCode!='409' && e.statusCode!='400') rethrow;
      final existing=await store.download(path);
      if(!listEquals(existing,bytes)) throw StateError('Different media already exists at $path. Use a new approved name.');
    }
    return store.getPublicUrl(path);
  }
}
