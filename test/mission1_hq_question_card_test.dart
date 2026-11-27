import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/widgets/learning_question_card.dart';
import 'package:kohntri_os_hq/widgets/vocabulary_workspace.dart';

Question row(QuestionType type,{Map<String,dynamic>? data,String? note='native-speaker validation pending',String? status='draft'})=>Question(
  id:'q',question:'Review this question',options:const ['first','second'],correctAnswerIndex:1,
  category:'Languages',explanation:'Recorded explanation',type:type,difficulty:Difficulty.medium,
  typeData:data,publicationStatus:status,reviewNote:note);
Future<void> render(WidgetTester t,Question q,VoidCallback publish) async {
  await t.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:LearningQuestionCard(
    question:q,onEdit:(){},onDelete:(){},onReview:(){},onPublish:publish)))));
  await t.pump();
}
void main(){
  test('metadata stays out of generic and language content writes',(){
    final l=LanguageQuestion.fromSupabase({'id':'q','theme_id':'t','language_type_id':'l','question':'Prompt',
      'options':['a','b'],'correct_answer_index':1,'type':'multipleChoice','points':10,'position':1,
      'status':'draft','review_note':'pending','audio_url':'https://example.org/audio.mp3'});
    final q=l.toQuestion();
    expect(q.publicationStatus,'draft');expect(q.reviewNote,'pending');
    expect(q.typeData?['audio_url'],'https://example.org/audio.mp3');
    expect(q.toSupabase().containsKey('review_note'),false);
    expect(l.toSupabase().containsKey('status'),false);
    expect(l.toAdminCache()['review_note'],'pending');
    final v=LessonVocabulary.fromSupabase({'id':'v','content_type':'language','term':'word','definition':'meaning','review_note':'pending'});
    expect(v.reviewNote,'pending');expect(v.toSupabase().containsKey('review_note'),false);
  });
  testWidgets('draft and review pending block publishing', (t) async {
    var published=0;await render(t,row(QuestionType.multipleChoice),()=>published++);
    expect(find.text('Draft'),findsOneWidget);expect(find.text('Review pending'),findsOneWidget);
    expect(find.text('Clear and save the review note before publishing.'),findsOneWidget);
    expect(t.widget<OutlinedButton>(find.ancestor(of:find.text('Publish'),matching:find.byWidgetPredicate((w)=>w is OutlinedButton))).onPressed,isNull);
    expect(published,0);expect(find.byType(Image),findsNothing);
    await render(t,row(QuestionType.multipleChoice,note:null),()=>published++);
    await t.ensureVisible(find.ancestor(of:find.text('Publish'),matching:find.byWidgetPredicate((w)=>w is OutlinedButton)));
    await t.tap(find.ancestor(of:find.text('Publish'),matching:find.byWidgetPredicate((w)=>w is OutlinedButton)));expect(published,1);
  });
  testWidgets('all supported types retain card and correct HQ answer', (t) async {
    for(final type in QuestionType.values){
      final data=type==QuestionType.fillBlank?{'sentenceParts':['Tehnki ',null],
        'wordBank':[{'id':'x','text':'ma'}],'correctAnswers':{'1':'x'}}:
        type==QuestionType.matchPairs?{'pairs':[{'left':'hello','right':'hi'}],
        'correctMatches':[{'leftIndex':0,'rightIndex':0}]}:null;
      await render(t,row(type,data:data),(){});
      expect(find.text(type.displayName),findsOneWidget);
      expect(find.text('Review this question'),findsOneWidget);
      if(type==QuestionType.fillBlank) expect(find.text('ma'),findsWidgets);
      if(type==QuestionType.matchPairs) expect(find.text('hello  ↔  hi'),findsOneWidget);
    }
  });
  testWidgets('vocabulary pending note disables theme publish', (t) async {
    var published=0;
    final v=LessonVocabulary(id:'v',contentType:'language',term:'word',definition:'meaning',status:'pending_approval',reviewNote:'pending');
    await t.pumpWidget(MaterialApp(home:Scaffold(body:VocabularyWorkspace(items:[v],canPublish:true,
      onAdd:(){},onImport:(){},onSubmit:(){},onPublish:()=>published++,onEdit:(_){},onDiscard:(_){}))));
    expect(find.text('Publication blocked: 1 vocabulary review notes must be cleared.'),findsOneWidget);
    expect(t.widget<OutlinedButton>(find.ancestor(of:find.text('Publish on Test1'),matching:find.byWidgetPredicate((w)=>w is OutlinedButton))).onPressed,isNull);
    expect(published,0);
  });
}
