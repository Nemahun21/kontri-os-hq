import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/widgets/vocabulary_workspace.dart';

void main(){
  final rows=[
    LessonVocabulary(id:'a',contentType:'language',term:'First',definition:'Meaning',difficulty:'easy',status:'draft',audioUrl:'https://example.com/a.mp3'),
    LessonVocabulary(id:'b',contentType:'language',term:'Second',definition:'Context',status:'pending_approval',imageUrl:'https://example.com/b.png'),
    LessonVocabulary(id:'c',contentType:'language',term:'Third',definition:'Story',difficulty:'hard',audioUrl:'invalid'),
  ];
  test('readiness reports actual links and assigned difficulty',(){
    final r=VocabularyReadiness.fromRows(rows);
    expect([r.total,r.classified,r.images,r.audio,r.drafts,r.pending],[3,2,1,1,1,1]);
    expect(filterVocabularyWorkspace(rows,stage:'unassigned').single.id,'b');
    expect(filterVocabularyWorkspace(rows,search:'context',status:'pending_approval').single.id,'b');
    expect(filterVocabularyWorkspace(rows,media:'missing_audio').map((r)=>r.id),['b','c']);
    expect(filterVocabularyWorkspace(rows,media:'both_linked'),isEmpty);
  });
  testWidgets('workspace search and preview do not mutate rows',(tester)async{
    final item=rows[2];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:VocabularyWorkspace(
      items:[item],canPublish:false,onAdd:(){},onImport:(){},onSubmit:(){},onPublish:(){},
      onEdit:(_){},onDiscard:(_){},
    ))));
    await tester.enterText(find.byType(TextField),'absent');
    await tester.pumpAndSettle();
    expect(find.text('No cards match your filters.'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'Third');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Preview'),100,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Learner preview'),findsOneWidget);
    expect(find.text('Audio not available'),findsOneWidget);
    expect(item.term,'Third');
  });
}
