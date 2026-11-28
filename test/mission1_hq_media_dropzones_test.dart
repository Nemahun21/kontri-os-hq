import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/screens/admin/heritage_pilot_screen.dart';
import 'package:kohntri_os_hq/screens/admin/lesson_vocab_mangt_screen.dart';
import 'package:kohntri_os_hq/widgets/media_drop_zone.dart';

const ref = '00000000-0000-0000-0000-000000000001';
Map<String, dynamic> discovery(String id) => {
  'id': id, 'title': 'Test title', 'objective': 'Test objective',
  'story': 'Test story', 'lesson_ids': [ref], 'question_ids': [ref],
  'sources': ['https://example.com/source'],
  'facts_approved': true, 'rights_approved': true, 'checks_approved': true,
};
LessonVocabulary draft(String id, {String? status = 'draft', String slug = 'krio_adu_hello'}) =>
  LessonVocabulary(id: id, contentType: 'language', themeId: ref,
    term: 'Test', definition: 'Test', fileSlug: slug, status: status,
    reviewNote: 'founder verification pending');
MediaLocalAsset asset(String name) => MediaLocalAsset(name, () async => 12,
  () async => Uint8List(12));

void main() {
  test('manual discovery appends without overwriting and resets approvals', () {
    final first = discovery('first-stop');
    final added = discovery('new-stop');
    final old = [first];
    final result = appendMissionDiscovery(old, added);
    expect(old.length, 1);
    expect(result.length, 2);
    expect(result.first, first);
    expect(result.last['id'], 'new-stop');
    for (final key in ['facts_approved', 'rights_approved', 'checks_approved']) {
      expect(result.last[key], isFalse);
      expect(added[key], isTrue);
    }
    expect(() => appendMissionDiscovery(old, first), throwsFormatException);
    expect(() => appendMissionDiscovery(old, {...added, 'story': ''}), throwsFormatException);
    expect(appendMissionDiscovery(old, {...added, 'sources': <String>[], 'verification_method':'pending'}).last['verification_method'], 'pending');
    expect(() => appendMissionDiscovery(old, {...added, 'sources': ['http://example.com']}), throwsFormatException);
    expect(() => appendMissionDiscovery(List.generate(50, (i) => discovery('stop-$i')), added), throwsFormatException);
  });

  test('verification options use existing manifest values and evidence rules', () {
    expect(missionVerificationLabels, {'pending':'Pending','founder':'Founder','community':'Community','document':'Documentary','web':'Web'});
    final stop=discovery('new-stop');
    expect(missionVerificationMethod(stop), 'web');
    expect(missionVerificationMethod({...stop,'sources': <String>[]}), 'pending');
    expect(missionVerificationEvidenceReady({...stop,'verification_method':'pending'}), isFalse);
    expect(missionVerificationEvidenceReady({...stop,'verification_method':'web'}), isTrue);
    expect(missionVerificationEvidenceReady({...stop,'verification_method':'web','sources': <String>[]}), isFalse);
    for(final method in ['founder','community','document']){
      final row={...stop,'verification_method':method,'sources': <String>[]};
      expect(missionVerificationEvidenceReady(row), isFalse);
      expect(missionVerificationEvidenceReady({...row,'verification_notes':'Evidence'}), isTrue);
    }
    expect(() => appendMissionDiscovery([], {...stop,'verification_method':'documentary'}), throwsFormatException);
    final saved=appendMissionDiscovery([], {...stop,'verification_method':'document','verification_notes':'Evidence','verified_by':ref,'verified_at':'2026-11-28'}).single;
    expect(saved['verification_method'], 'document');
    expect(saved['verification_notes'], 'Evidence');
    expect(saved['facts_approved'], isFalse);
    expect(saved.containsKey('verified_by'), isFalse);
    expect(saved.containsKey('verified_at'), isFalse);
  });

  test('heritage exact filename matching stays unchanged', () {
    final stops = [discovery('cotton-tree'), {...discovery('fort'), 'title': 'Fort'}];
    expect(matchMissionMedia('cotton_tree.png', stops), 0);
    expect(matchMissionMedia('fort.mp3', stops), 1);
    expect(matchMissionMedia('unknown.png', stops), isNull);
    expect(matchMissionMedia('cotton_tree.png', [...stops, discovery('cotton_tree')]), isNull);
  });

  test('bulk vocabulary accepts unique saved drafts only and preserves review note', () {
    final row = draft('1');
    expect(matchVocabularyDraftMedia('krio_adu_hello.png', [row]), same(row));
    expect(matchVocabularyDraftMedia('krio_adu_hello.mp3', [row]), same(row));
    expect(matchVocabularyDraftMedia('krio_adu_hello_v0123456789abcdef.mp3', [row]), same(row));
    expect(matchVocabularyDraftMedia('hello.png', [row]), isNull);
    expect(matchVocabularyDraftMedia('krio_adu_hello.wav', [row]), isNull);
    expect(matchVocabularyDraftMedia('krio_adu_hello.png', [row, draft('2')]), isNull);
    expect(matchVocabularyDraftMedia('krio_adu_hello.png', [draft('2', status: 'published')]), isNull);
    expect(matchVocabularyDraftMedia('krio_adu_hello.png', [draft('2', status: 'pending_approval')]), isNull);
    expect(row.reviewNote, 'founder verification pending');
  });

  test('size guard rejects before reading oversized assets', () async {
    var read = false;
    final file = MediaLocalAsset('oversize.png', () async => 101, () async {
      read = true;
      return Uint8List(101);
    });
    await expectLater(file.readChecked(100), throwsFormatException);
    expect(read, isFalse);
  });

  testWidgets('browse fallback uses the same lazy asset callback', (tester) async {
    var received = <MediaLocalAsset>[];
    final file = asset('test.png');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaDropZone(
      label: 'Image', help: 'PNG', extensions: const ['png'], enabled: true,
      enableDrop: false, browseOverride: () async => [file],
      onFiles: (files) async { received = files; },
    ))));
    await tester.tap(find.text('Browse files'));
    await tester.pumpAndSettle();
    expect(received.single, same(file));
  });

  testWidgets('single-file limit rejects multiple files without invoking upload', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaDropZone(
      label: 'Image', help: 'PNG', extensions: const ['png'], enabled: true,
      enableDrop: false, browseOverride: () async => [asset('a.png'), asset('b.png')],
      onFiles: (_) async { calls++; },
    ))));
    await tester.tap(find.text('Browse files'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Select exactly one file.'), findsOneWidget);
  });

  testWidgets('disabled drop zone cannot browse', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaDropZone(
      label: 'Image', help: 'PNG', extensions: const ['png'], enabled: false,
      enableDrop: false, browseOverride: () async { calls++; return [asset('a.png')]; },
      onFiles: (_) async {},
    ))));
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    expect(calls, 0);
  });
}
