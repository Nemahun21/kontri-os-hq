import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kohntri_os_hq/models/heritage_mission_manifest.dart';
export 'package:kohntri_os_hq/models/heritage_mission_manifest.dart';

class HeritagePilotScreen extends StatefulWidget {
  const HeritagePilotScreen({super.key});
  @override
  State<HeritagePilotScreen> createState()=>_HeritagePilotScreenState();
}
class _HeritagePilotScreenState extends State<HeritagePilotScreen> {
  bool _loading=true,_failed=false;
  Map<String,Map<String,dynamic>> _lessons={},_questions={};
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState((){_loading=true;_failed=false;});
    try{
      final db=Supabase.instance.client;
      if(await db.rpc('is_active_admin')!=true)throw StateError('Active admin required');
      final lessons=await db.from('lesson_vocabulary').select('id,term,definition,category,image_url,audio_url').eq('content_type','adventure').inFilter('id',heritageStops.expand((s)=>s.lessonIds).toSet().toList());
      final questions=await db.from('questions').select('id,question,category,type,difficulty,image_urls,options,correct_answer_index').inFilter('id',heritageStops.expand((s)=>s.questionIds).toSet().toList());
      if(!mounted)return;
      setState((){
        _lessons={for(final row in lessons) row['id'].toString():row};
        _questions={for(final row in questions) row['id'].toString():row};
        _loading=false;
      });
    }catch(_){if(mounted)setState((){_loading=false;_failed=true;});}
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('Monuments & Relics'),actions:[
        IconButton(onPressed:_loading?null:_load,tooltip:'Refresh sources',icon:const Icon(Icons.refresh)),
      ]),
      body:_loading?const Center(child:CircularProgressIndicator()):
        _failed?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Could not load pilot sources.'),
          TextButton(onPressed:_load,child:const Text('Retry')),
        ])):
        ListView(padding:const EdgeInsets.all(16),children:[
          const Text('Pilot source workbench',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
          Text('Test1 • Shared preview contract v$heritageMissionVersion • Not published'),
          const SizedBox(height:12),
          Text('${_lessons.length} distinct lesson references • ${_questions.length} question references available'),
          const SizedBox(height:12),
          for(var i=0;i<heritageStops.length;i++) Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${i+1}. ${heritageStops[i].title}',style:Theme.of(context).textTheme.titleLarge),
            Text(heritageStops[i].objective),
            const SizedBox(height:8),
            Text(heritageStops[i].story),
            const SizedBox(height:8),
            const Text('Source references — review and rights pending',style:TextStyle(fontWeight:FontWeight.w600)),
            for(final url in heritageStops[i].sources) SelectableText(url,style:TextStyle(color:Theme.of(context).colorScheme.primary,fontSize:12)),
            const SizedBox(height:12),
            const Text('Existing lesson sources',style:TextStyle(fontWeight:FontWeight.bold)),
            for(final id in heritageStops[i].lessonIds) Padding(padding:const EdgeInsets.symmetric(vertical:6),child:
              _lessons[id]==null?const Text('Referenced lesson unavailable'):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${_lessons[id]!['term']} · ${_lessons[id]!['category']}'),
                Text('${_lessons[id]!['definition']}'),
                Text(_lessons[id]!['image_url']==null?'No image link':'Image link present; verify rights and playback'),
              ])),
            const SizedBox(height:8),
            const Text('Candidate knowledge checks',style:TextStyle(fontWeight:FontWeight.bold)),
            for(final id in heritageStops[i].questionIds) Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Text(
              _questions[id]==null?'Referenced question unavailable':'${_questions[id]!['question']} • ${_questions[id]!['difficulty']} • ${supportedHeritageQuestion(_questions[id]!) ? 'Preview supported' : 'Needs review'}')),
            const Divider(),
            Text('Still required: ${heritageStops[i].gap}'),
            const Text('Source verification and publication approval pending.'),
          ]))),
          const Text('Existing record IDs and level mappings remain unchanged. Editing and publication are disabled here until the shared mission contract is approved.'),
        ]),
    );
  }
}
