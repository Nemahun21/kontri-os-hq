import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/preview_question_screen.dart';
import 'package:kohntri_os_hq/question_types/audio_player_widget.dart' as audio;

bool hasReviewNote(String? note) => note?.trim().isNotEmpty == true;

// Do not assume missing metadata means draft or published.
String? questionPublishBlock(Question q) {
  if (q.publicationStatus != 'draft') return 'Refresh: this is not a known draft.';
  if (q.reviewNote != null) return 'Clear and save the review note before publishing.';
  return null;
}

bool _https(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// HQ-only read-only card. Interactive behavior stays in existing preview/editor.
class LearningQuestionCard extends StatelessWidget {
  final Question question;
  final String? scope;
  final bool pendingSync;
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onReview, onPublish;
  const LearningQuestionCard({super.key, required this.question, this.scope,
    this.pendingSync = false, required this.onEdit, required this.onDelete,
    this.onReview, this.onPublish});

  @override
  Widget build(BuildContext context) {
    final q = question;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFA7D9B9) : const Color(0xFF245B43);
    final ink = dark ? const Color(0xFFF0F6F2) : const Color(0xFF18372C);
    final surface = dark ? const Color(0xFF23362F) : const Color(0xFFF6F4ED);
    final review = hasReviewNote(q.reviewNote);
    final blocked = questionPublishBlock(q);
    final data = q.typeData ?? const <String,dynamic>{};
    final images = q.imageUrls?.entries.where((e) => _https(e.value)).toList() ?? [];
    final audioUrl = data['audio_url']?.toString();
    final words = (data['wordBank'] is List ? data['wordBank'] as List : const []).whereType<Map>().toList();
    final pairs = (data['pairs'] is List ? data['pairs'] as List : const []).whereType<Map>().toList();
    final matches = (data['correctMatches'] is List ? data['correctMatches'] as List : const []).whereType<Map>().toList();
    final answers = data['correctAnswers'] is Map ? data['correctAnswers'] as Map : const {};
    final sentence = data['sentenceParts'] is List ? data['sentenceParts'] as List : const [];
    Widget section(String label, String? value) => value?.trim().isNotEmpty != true
      ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top:10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(label, style: TextStyle(color:accent,fontWeight:FontWeight.w600,fontSize:12)),
          const SizedBox(height:4), Text(value!,style:TextStyle(color:ink)),
        ]));
    Widget option(String text, {bool correct=false, String? image}) => Container(
      width:double.infinity,margin:const EdgeInsets.only(top:6),padding:const EdgeInsets.all(10),
      decoration:BoxDecoration(color:correct?accent.withOpacity(.13):theme.colorScheme.surface,
        borderRadius:BorderRadius.circular(10),border:Border.all(color:correct?accent:theme.dividerColor)),
      child:Row(children:[if(_https(image)) ...[SizedBox(width:56,height:48,child:Image.network(image!,fit:BoxFit.contain,
        errorBuilder:(_,__,___)=>const SizedBox.shrink())),const SizedBox(width:8)],
        Expanded(child:Text(text,style:TextStyle(color:ink))),
        if(correct) Icon(Icons.check_circle,color:accent,semanticLabel:'Correct answer')]));
    final body = <Widget>[];
    if(q.type == QuestionType.fillBlank) {
      if(sentence.isNotEmpty) body.add(Text(sentence.map((s)=>s?.toString() ?? '____').join(),style:TextStyle(color:ink,fontSize:17)));
      if(words.isNotEmpty) body.add(Wrap(spacing:6,runSpacing:4,children:[for(final word in words)
        Chip(label:Text(word['text']?.toString() ?? ''))]));
      final keys = answers.keys.toList()..sort((a,b)=>(int.tryParse(a.toString())??0).compareTo(int.tryParse(b.toString())??0));
      for(final key in keys) {
        final found = words.where((w)=>w['id']==answers[key]);
        if(found.isNotEmpty && found.first['text']!=null) body.add(option(found.first['text'].toString(),correct:true));
      }
    } else if(q.type == QuestionType.matchPairs) {
      // Follow the recorded mapping, never manufacture a correct pair.
      for(final match in matches) {
        final l = match['leftIndex'], r = match['rightIndex'];
        if(l is int && r is int && l>=0 && r>=0 && l<pairs.length && r<pairs.length
          && pairs[l]['left']!=null && pairs[r]['right']!=null) {
          body.add(option('${pairs[l]['left']}  ↔  ${pairs[r]['right']}',correct:true));
        }
      }
      if(matches.isEmpty && pairs.isNotEmpty) {
        body.add(Wrap(spacing:6,children:[for(final pair in pairs) ...[
          if(pair['left']!=null) Chip(label:Text(pair['left'].toString())),
          if(pair['right']!=null) Chip(label:Text(pair['right'].toString())),
        ]]));
      }
    } else {
      for(var i=0;i<q.options.length;i++) {
        final image=q.imageUrls?['$i'];
        if(q.options[i].trim().isNotEmpty || _https(image)) body.add(option(q.options[i],
          correct:i==q.correctAnswerIndex,image:(q.type==QuestionType.imageChoice||q.type==QuestionType.dragAndDrop)?image:null));
      }
    }
    return Card(elevation:0,margin:const EdgeInsets.only(bottom:12),color:surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(spacing:8,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[
          Text(scope ?? q.category,style:TextStyle(color:accent,fontWeight:FontWeight.w700)),
          Text(q.type.displayName), if(q.level!=null) Text('${q.category=='Languages'?'Position':'Level'} ${q.level}'),
          if(q.category!='Languages') Text(q.difficulty.name), Text('${q.points} pts'),
          if(q.publicationStatus=='draft') const Chip(label:Text('Draft')),
          if(review) const Chip(label:Text('Review pending')),
          if(pendingSync) const Chip(label:Text('Pending sync')),
        ]),
        const SizedBox(height:10),
        if(q.type!=QuestionType.imageChoice && q.type!=QuestionType.dragAndDrop)
          for(final image in images) Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:220,maxHeight:144),
            child:Image.network(image.value,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()))),
        Text(q.question,style:TextStyle(color:ink,fontSize:20,fontWeight:FontWeight.w700)),
        section('Scenario',q.scenario),
        if(_https(audioUrl)) audio.AudioPlayerWidget(audioUrl:audioUrl!,
          trimStart:(data['trim_start'] as num?)?.toDouble(),trimEnd:(data['trim_end'] as num?)?.toDouble()),
        ...body,
        section('Explanation',q.explanation),section('Consequence',q.wrongConsequence),section('Cultural context',q.culturalContext),
        if(review) section('Editorial review note (HQ only)',q.reviewNote),
        if(onPublish!=null && blocked!=null) section('Publication blocked',blocked),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:4,children:[
          TextButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PreviewQuestionScreen(
            questionData:q.toSupabase(),questionIndex:(q.level??1)-1))),icon:const Icon(Icons.visibility_outlined),label:const Text('Preview')),
          TextButton.icon(onPressed:onEdit,icon:const Icon(Icons.edit_outlined),label:const Text('Edit question')),
          if(onReview!=null) TextButton.icon(onPressed:onReview,icon:const Icon(Icons.fact_check_outlined),label:const Text('Edit review note')),
          if(onPublish!=null) OutlinedButton.icon(onPressed:blocked==null?onPublish:null,icon:const Icon(Icons.publish),label:const Text('Publish')),
          TextButton.icon(onPressed:onDelete,icon:const Icon(Icons.delete_outline),label:const Text('Delete')),
        ]),
      ])));
  }
}
