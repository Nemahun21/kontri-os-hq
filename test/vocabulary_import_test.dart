import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/vocabulary_import_service.dart';
import 'package:kohntri_os_hq/services/vocabulary_asset_service.dart';
import 'package:kohntri_os_hq/services/xlsx_reader.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('CSV preserves linguistic Unicode and quoted multiline examples', () {
    final rows = VocabularyImportService.parse(bytes(
      '\uFEFFterm,definition,example,file_slug\r\nYɛmɔi,Mother-in-law,"A line\nsecond line",mende_yemoi_mother_in_law\r\n'));
    expect(rows.single['term'], 'Yɛmɔi');
    expect(rows.single['example'], 'A line\nsecond line');
  });

  test('TXT supports tab delimiter and malformed rows are rejected', () {
    expect(VocabularyImportService.parse(bytes('word\ttranslation\nBuuya\tHello'), txt: true).single['word'], 'Buuya');
    expect(() => VocabularyImportService.parse(bytes('term,definition\nA')), throwsFormatException);
    expect(() => VocabularyImportService.parse(bytes('term,definition,term\nA,B,C')), throwsFormatException);
  });

  test('Slugs and paths are strict, language audio and shared images are separate', () {
    expect(VocabularyImportService.validSlug('mende_yemoi_mother_in_law_vaaeea03a06bf'), isTrue);
    expect(VocabularyImportService.validSlug('mende_Yɛmɔi'), isFalse);
    expect(VocabularyAssetService.validPath('images/drum.png', audio: false), isTrue);
    expect(VocabularyAssetService.validPath('audio/mende/mende_mbilii_drum.mp3', audio: true), isTrue);
    expect(VocabularyAssetService.validPath('images/../drum.png', audio: false), isFalse);
    expect(VocabularyAssetService.validPath('images/drum.mp3', audio: false), isFalse);
  });

  test('Legacy suggestion uses the same basic transliteration as the backfill', () {
    expect(VocabularyImportService.suggestedSlug('mende','Yɛmɔi','Mother in-law'),
      'mende_yemoi_mother_in_law');
    expect(VocabularyImportService.suggestedSlug('temne','ŋə','Example'), 'temne_nge_example');
  });

  test('Workbook pads trailing blank cells', () {
    final csv = XlsxReader.toCsv([XlsxSheet('A', [['term','definition','example'], ['a','b']])]);
    expect(VocabularyImportService.parse(csv).single['example'], '');
  });

  test('Workbook refuses incompatible header layouts', () {
    expect(() => XlsxReader.toCsv([
      XlsxSheet('A', [['term','definition'], ['a','b']]),
      XlsxSheet('B', [['definition','term'], ['c','d']]),
    ]), throwsFormatException);
  });

  test('Vocabulary model preserves slug and existing media', () {
    final model = LessonVocabulary.fromSupabase({
      'id': 'existing', 'content_type':'language', 'theme_id':'theme',
      'term':'Buuya', 'definition':'Hello', 'file_slug':'mende_buuya_hello',
      'audio_url':'https://example.com/audio.mp3', 'image_url':'https://example.com/image.png',
    });
    expect(model.toSupabase()['file_slug'], 'mende_buuya_hello');
    expect(model.toSupabase()['audio_url'], 'https://example.com/audio.mp3');
    expect(model.toSupabase()['image_url'], 'https://example.com/image.png');
  });
}
