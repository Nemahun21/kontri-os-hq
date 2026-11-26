import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/screens/admin/heritage_pilot_screen.dart';

void main(){
  const header='id,title,objective,story,lesson_ids,question_ids,sources';
  const lesson='b8eb5b59-369c-4922-bf68-27a8dc3f3d6a';
  const question='ab728eb6-8a48-4e31-b1f0-960670b7cad8';
  const row='cotton-tree,Cotton Tree,Memory,"Story, line one\nLine ""two""",$lesson,$question,https://example.org';
  test('CSV preserves multiline and quoted stories',(){
    final rows=parseMissionText('$header\n$row');
    expect(rows.length,2);
    expect(rows[1][3],'Story, line one\nLine "two"');
    expect(mergeMissionRows(rows,[]).single['facts_approved'],false);
  });
  test('TXT supports tab separators',(){
    final rows=parseMissionText('id\ttitle\ncotton-tree\tCotton Tree');
    expect(rows,[['id','title'],['cotton-tree','Cotton Tree']]);
  });
  test('repeat import preserves media and review; changed story resets review',(){
    final rows=parseMissionText('$header\n$row');
    final initial=mergeMissionRows(rows,[]);
    initial.single['image_path']='monuments-and-relics/cotton-tree/heritage_cotton_tree_image.png';
    initial.single['facts_approved']=true;
    final unchanged=mergeMissionRows(rows,initial);
    expect(unchanged.length,1);
    expect(unchanged.single['image_path'],initial.single['image_path']);
    expect(unchanged.single['facts_approved'],true);
    final changed=mergeMissionRows(parseMissionText('$header\n$row'.replaceFirst('Story, line one','Updated story')),initial);
    expect(changed.single['facts_approved'],false);
    expect(initial.single['facts_approved'],true);
  });
  test('duplicate, malformed and unclosed input fails',(){
    expect(()=>mergeMissionRows(parseMissionText('$header\n$row\n$row'),[]),throwsFormatException);
    expect(()=>mergeMissionRows(parseMissionText('id,title\nbad,Bad'),[]),throwsFormatException);
    expect(()=>parseMissionText('id,title\nx,"open'),throwsFormatException);
  });
}
