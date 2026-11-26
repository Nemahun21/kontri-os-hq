import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/models/heritage_mission_manifest.dart';
void main(){
  test('shared ordered contract has stable stop identifiers and existing references',(){
    expect(heritageMissionVersion,1);
    expect(heritageStops.map((s)=>s.id),['cotton-tree','bunce-island','national-museum','railway-museum']);
    expect(heritageStops.expand((s)=>s.questionIds).toSet().length,6);
    expect(heritageStops.expand((s)=>s.lessonIds).toSet().length,4);
    expect(heritageStops.every((s)=>s.sources.isNotEmpty && s.story.isNotEmpty),isTrue);
  });
  test('knowledge checks reject missing, malformed and unsupported data',(){
    expect(supportedHeritageQuestion({'type':'trueFalse','question':'A question','options':['True','False'],'correct_answer_index':0}),isTrue);
    expect(supportedHeritageQuestion({'type':'textInput','question':'A question','options':['answer'],'correct_answer_index':0}),isTrue);
    expect(supportedHeritageQuestion({'type':'multipleChoice','question':'A question','options':['One','Two'],'correct_answer_index':2}),isFalse);
    expect(supportedHeritageQuestion({'type':'imageChoice','question':'A question','options':['One','Two'],'correct_answer_index':0}),isFalse);
    expect(supportedHeritageQuestion({}),isFalse);
  });
}
