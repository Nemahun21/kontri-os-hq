import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/controllers/vocabulary_draft_controller.dart';
import 'package:kohntri_os_hq/models/vocabulary_import_batch.dart';
import 'package:kohntri_os_hq/services/vocabulary_import_service.dart';

void main() {
  test('dropped PNG can be assigned canonical name without changing source', () async {
    final bytes = Uint8List.fromList([137,80,78,71,13,10,26,10,0,0,0,0]);
    final source = VocabularyLocalAsset('IMG_001.PNG', () async => bytes.length, () async => bytes);
    final media = await DraftMedia.load(source, audio: false);
    final slug = VocabularyImportService.suggestedSlug('mende','Mbilii','Drum');
    final renamed = media.named('$slug.png');
    expect(media.name, 'IMG_001.PNG');
    expect(renamed.name, 'mende_mbilii_drum.png');
    expect(await renamed.read(), bytes);
  });
  test('invalid format and media signature are rejected before upload', () async {
    final bytes = Uint8List(16);
    for (final name in ['bad.wav','bad.mp3']) {
      final source = VocabularyLocalAsset(name, () async => bytes.length, () async => bytes);
      await expectLater(DraftMedia.load(source, audio: true), throwsFormatException);
    }
  });
  test('oversize file is rejected before reading', () async {
    final source = VocabularyLocalAsset('bad.mp3', () async => 11*1024*1024,
      () async => throw StateError('must not read'));
    await expectLater(DraftMedia.load(source, audio: true), throwsFormatException);
  });
}
