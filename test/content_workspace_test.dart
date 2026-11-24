import 'package:flutter_test/flutter_test.dart';
import 'package:kohntri_os_hq/widgets/content_workspace_metrics.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/controllers/vocabulary_draft_controller.dart';

void main() {
  test('metrics count records with either missing asset once', () {
    final coverage=ContentCoverage.fromRows([
      {'questions':3,'vocabulary':10,'images':7,'audio':5,'complete':4},
      {'questions':2,'vocabulary':2,'images':1,'audio':1,'complete':1},
    ]);
    expect(coverage.themes,2);
    expect(coverage.vocabulary,12);
    expect(coverage.missing,7);
    expect(coverage.fraction(coverage.images),closeTo(8/12,.001));
    expect(const ContentCoverage().fraction(0),0);
  });
  test('legacy vocabulary snapshot preserves null media and original position', () {
    final row=LessonVocabulary.fromSupabase({
      'id':'old','content_type':'language','theme_id':'theme',
      'term':'Legacy word','definition':'Meaning','position':11,
    });
    final snapshot=row.toSupabase();
    expect(row.id,'old');
    expect(snapshot['position'],11);
    expect(snapshot['image_url'],isNull);
    expect(snapshot['audio_url'],isNull);
    expect(snapshot['file_slug'],isNull);
    expect(snapshot.containsKey('audio_url'),isTrue);
  });
  test('shared path remains stable when local revision is requested', () {
    expect(VocabularyDraftController.resolveImagePath(sharedPath:'images/drum.png',
      slug:'krio_drum',revision:'0123456789abcdef'),'images/drum.png');
  });
}
