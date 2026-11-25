import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/screens/admin/heritage_pilot_screen.dart';

void main(){
  test('pilot keeps four ordered candidate stops and six distinct questions',(){
    expect(heritageStops.map((s)=>s.title),['Cotton Tree','Bunce Island','National Museum','National Railway Museum']);
    expect(heritageStops.expand((s)=>s.questionIds).toSet().length,6);
    expect(heritageStops.expand((s)=>s.lessonIds).toSet().length,4);
  });
}
