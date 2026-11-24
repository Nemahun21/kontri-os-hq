import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/controllers/vocabulary_draft_controller.dart';
import 'package:kohntri_os_hq/models/vocabulary_import_batch.dart';
import 'package:kohntri_os_hq/services/vocabulary_import_service.dart';
import 'package:kohntri_os_hq/services/audio_import_service.dart';

void main() {
  test('immutable revision preserves slug and rejects cross-word audio', () {
    final path = VocabularyDraftController.revisionPath(
      'audio/krio/krio_tehl_tenki_gratitude.mp3', '0123456789abcdef');
    expect(path, 'audio/krio/krio_tehl_tenki_gratitude_v0123456789abcdef.mp3');
    expect(VocabularyImportService.validLanguageAudioPath(path,'krio','krio_tehl_tenki_gratitude'), isTrue);
    expect(VocabularyImportService.validLanguageAudioPath(path,'mende','mende_tehl_tenki_gratitude'), isFalse);
    expect(VocabularyImportService.validLanguageAudioPath('audio/krio/krio_tehl_tenki_gratitude_other.mp3',
      'krio','krio_tehl_tenki_gratitude'), isFalse);
  });
  test('MP3 bypasses conversion and preserves its bytes', () async {
    final bytes = Uint8List.fromList([73,68,51,0,0,0,0,0,0,0,0,0]);
    final source = VocabularyLocalAsset('voice.MP3', () async => bytes.length, () async => bytes);
    expect(await AudioImportService.prepare(source, converter: (_, __, ___) async {
      throw StateError('MP3 must not be converted');
    }), bytes);
  });
  test('common audio formats normalize through one converter', () async {
    final input = Uint8List.fromList([1,2,3,4]);
    final mp3 = Uint8List.fromList([73,68,51,0,0,0,0,0,0,0,0,0]);
    for (final ext in AudioImportService.extensions.where((e) => e != 'mp3')) {
      final source = VocabularyLocalAsset('voice.$ext', () async => input.length, () async => input);
      final result = await AudioImportService.prepare(source, converter: (bytes, extension, max) async {
        expect(bytes, input);
        expect(extension, ext);
        expect(max, 10 * 1024 * 1024);
        return mp3;
      });
      expect(result, mp3);
    }
  });
  test('invalid or excessive converter output is rejected', () async {
    final input = Uint8List(12);
    final source = VocabularyLocalAsset('voice.wav', () async => input.length, () async => input);
    await expectLater(AudioImportService.prepare(source,
      converter: (_, __, ___) async => Uint8List(12)), throwsFormatException);
    await expectLater(AudioImportService.prepare(source,
      converter: (_, __, ___) async => Uint8List(11 * 1024 * 1024)), throwsFormatException);
  });
  test('real WAV to MP3 conversion (opt-in desktop FFmpeg smoke test)', () async {
    // 0.1 seconds of mono PCM silence, valid WAV header and data.
    final wav = Uint8List(44 + 8820);
    final data = ByteData.sublistView(wav);
    wav.setRange(0,4,'RIFF'.codeUnits);
    data.setUint32(4,wav.length - 8,Endian.little);
    wav.setRange(8,12,'WAVE'.codeUnits);
    wav.setRange(12,16,'fmt '.codeUnits);
    data.setUint32(16,16,Endian.little);
    data.setUint16(20,1,Endian.little);
    data.setUint16(22,1,Endian.little);
    data.setUint32(24,44100,Endian.little);
    data.setUint32(28,88200,Endian.little);
    data.setUint16(32,2,Endian.little);
    data.setUint16(34,16,Endian.little);
    wav.setRange(36,40,'data'.codeUnits);
    data.setUint32(40,wav.length - 44,Endian.little);
    final source = VocabularyLocalAsset('voice.wav', () async => wav.length, () async => wav);
    final media = await DraftMedia.load(source, audio: true);
    expect(media.convertedToMp3, isTrue);
    expect(media.name, 'voice.wav');
    expect(media.bytes.length, greaterThan(12));
  }, skip: !const bool.fromEnvironment('KONTRIOS_FFMPEG_TEST'));

  test('shared image path is independent of language slug', () {
    for (final slug in ['mende_example_drum', 'temne_example_drum', 'krio_example_drum']) {
      expect(VocabularyDraftController.resolveImagePath(
        sharedPath: 'images/drum.png', slug: slug), 'images/drum.png');
    }
    expect(VocabularyDraftController.resolveImagePath(
      slug: 'mende_example_drum', localExtension: 'png'), 'images/mende_example_drum.png');
    expect(() => VocabularyDraftController.resolveImagePath(
      sharedPath: 'audio/mende/drum.mp3'), throwsFormatException);
  });
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
    for (final name in ['bad.txt','bad.mp3']) {
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
