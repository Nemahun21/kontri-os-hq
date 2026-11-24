import 'package:flutter/material.dart';

class ContentCoverage {
  final int themes, questions, vocabulary, images, audio, complete;
  const ContentCoverage({this.themes=0,this.questions=0,this.vocabulary=0,this.images=0,this.audio=0,this.complete=0});
  factory ContentCoverage.fromRows(Iterable<Map<String,dynamic>> rows) {
    var t=0,q=0,v=0,i=0,a=0,c=0;
    for (final r in rows) {
      t++; q+=(r['questions'] as num).toInt(); v+=(r['vocabulary'] as num).toInt();
      i+=(r['images'] as num).toInt(); a+=(r['audio'] as num).toInt(); c+=(r['complete'] as num).toInt();
    }
    return ContentCoverage(themes:t,questions:q,vocabulary:v,images:i,audio:a,complete:c);
  }
  int get missing => vocabulary-complete;
  double fraction(int count) => vocabulary==0 ? 0 : (count/vocabulary).clamp(0,1).toDouble();
}

class WorkspaceMetrics extends StatelessWidget {
  final Map<String,String> values;
  const WorkspaceMetrics({super.key,required this.values});
  @override
  Widget build(BuildContext context) => Wrap(spacing:10,runSpacing:10,children: [
    for (final entry in values.entries)
      Container(width:150,padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(entry.key,style:Theme.of(context).textTheme.labelMedium),
          const SizedBox(height:4),Text(entry.value,style:Theme.of(context).textTheme.headlineSmall),
        ])),
  ]);
}

class CoverageLines extends StatelessWidget {
  final ContentCoverage coverage;
  const CoverageLines({super.key,required this.coverage});
  @override
  Widget build(BuildContext context) => Column(children:[
    _line(context,'Images',coverage.images),const SizedBox(height:8),
    _line(context,'Recordings',coverage.audio),
  ]);
  Widget _line(BuildContext context,String label,int count) => Row(children:[
    SizedBox(width:85,child:Text(label,style:Theme.of(context).textTheme.bodySmall)),
    Expanded(child:LinearProgressIndicator(value:coverage.fraction(count),minHeight:5,borderRadius:BorderRadius.circular(8))),
    const SizedBox(width:12),
    SizedBox(width:80,child:Text('$count / ${coverage.vocabulary}',textAlign:TextAlign.end)),
  ]);
}
