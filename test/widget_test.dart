import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';

void main() {
  test('draft vocabulary retains stable slug, difficulty, and media', () {
    final entry = LessonVocabulary.fromSupabase({
      'id':'existing-id', 'content_type':'language',
      'theme_id':'theme-id', 'term':'test', 'definition':'test definition',
      'difficulty':'medium', 'position':5, 'file_slug':'krio_test_test_definition',
      'status':'pending_approval', 'audio_url':'https://example.invalid/audio.mp3',
      'image_url':'https://example.invalid/image.png',
    });
    expect(entry.id,'existing-id');
    expect(entry.status,'pending_approval');
    final data=entry.toSupabase();
    expect(data['file_slug'],'krio_test_test_definition');
    expect(data['difficulty'],'medium');
    expect(data['position'],5);
    expect(data['audio_url'],entry.audioUrl);
    expect(data['image_url'],entry.imageUrl);
    expect(data.containsKey('status'),isFalse);
    expect(data.containsKey('id'),isFalse);
  });
  test('legacy entries without slug or status still deserialize', () {
    final entry=LessonVocabulary.fromSupabase({'id':'legacy','term':'old'});
    expect(entry.status,isNull);
    expect(entry.toSupabase().containsKey('file_slug'),isFalse);
  });
}
