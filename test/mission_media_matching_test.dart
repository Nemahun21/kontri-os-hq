import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/screens/admin/heritage_pilot_screen.dart';

void main() {
  final stops = <Map<String,dynamic>>[
    {'id':'cotton-tree','title':'Cotton Tree'},
    {'id':'railway-museum','title':'National Railway Museum'},
  ];
  test('normalizes names without changing supported extensions', () {
    expect(normalizeMissionFilename(' Cotton Tree (1).PNG '), 'cotton_tree_1.png');
    expect(normalizeMissionFilename('Railway--Museum.MP3'), 'railway_museum.mp3');
    expect(() => normalizeMissionFilename('archive.exe'), throwsFormatException);
  });
  test('matches exact stop ID or title only', () {
    expect(matchMissionMedia('Cotton Tree.PNG',stops),0);
    expect(matchMissionMedia('National Railway Museum.mp3',stops),1);
    expect(matchMissionMedia('railway-museum.jpg',stops),1);
    expect(matchMissionMedia('chorus_singers.png',stops),isNull);
    expect(matchMissionMedia('cotton_tree_1.png',stops),isNull);
  });
  test('ambiguous matches are not assigned', () {
    expect(matchMissionMedia('cotton_tree.png',[
      ...stops, {'id':'another','title':'Cotton Tree'},
    ]),isNull);
  });
}
