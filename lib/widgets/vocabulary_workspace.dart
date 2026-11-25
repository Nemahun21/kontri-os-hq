import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';

const workspaceStages = ['easy', 'medium', 'hard'];
String workspaceStage(String? value) => switch (value) {
  'easy' => 'Beginner', 'medium' => 'Intermediate', 'hard' => 'Advanced', _ => 'Unassigned',
};
String workspaceObjective(String? value) => switch (value) {
  'easy' => 'Recognize • connect a word with its meaning.',
  'medium' => 'Apply • use language in familiar situations.',
  'hard' => 'Understand • explore cultural meaning and context.',
  _ => 'Choose a stage based on the learning objective.',
};
bool workspaceHasLink(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
String workspaceStatus(LessonVocabulary row) => row.status == 'draft'
    ? 'draft' : row.status == 'pending_approval' ? 'pending_approval' : 'published';
String workspaceStatusLabel(LessonVocabulary row) => switch (workspaceStatus(row)) {
  'draft' => 'Draft', 'pending_approval' => 'Pending approval', _ => 'Published',
};

class VocabularyReadiness {
  final int total, classified, images, audio, drafts, pending;
  const VocabularyReadiness(this.total,this.classified,this.images,this.audio,this.drafts,this.pending);
  factory VocabularyReadiness.fromRows(List<LessonVocabulary> rows) => VocabularyReadiness(
    rows.length,
    rows.where((r) => workspaceStages.contains(r.difficulty)).length,
    rows.where((r) => workspaceHasLink(r.imageUrl)).length,
    rows.where((r) => workspaceHasLink(r.audioUrl)).length,
    rows.where((r) => workspaceStatus(r) == 'draft').length,
    rows.where((r) => workspaceStatus(r) == 'pending_approval').length,
  );
}
List<LessonVocabulary> filterVocabularyWorkspace(List<LessonVocabulary> rows, {
  String search = '', String stage = 'all', String status = 'all', String media = 'all',
}) {
  final needle = search.trim().toLowerCase();
  return rows.where((r) {
    final text = [r.term,r.definition,r.pronunciation,r.example,r.fileSlug].whereType<String>().join(' ').toLowerCase();
    if (!text.contains(needle)) return false;
    if (stage == 'unassigned' && workspaceStages.contains(r.difficulty)) return false;
    if (stage != 'all' && stage != 'unassigned' && r.difficulty != stage) return false;
    if (status != 'all' && workspaceStatus(r) != status) return false;
    if (media == 'missing_audio' && workspaceHasLink(r.audioUrl)) return false;
    if (media == 'missing_image' && workspaceHasLink(r.imageUrl)) return false;
    if (media == 'both_linked' && !(workspaceHasLink(r.audioUrl) && workspaceHasLink(r.imageUrl))) return false;
    return true;
  }).toList(growable: false);
}

/// Presentation-only workspace. All writes remain in the caller's existing RPC services.
class VocabularyWorkspace extends StatefulWidget {
  final List<LessonVocabulary> items;
  final bool canPublish;
  final VoidCallback onAdd,onImport,onSubmit,onPublish;
  final ValueChanged<LessonVocabulary> onEdit,onDiscard;
  const VocabularyWorkspace({super.key,required this.items,required this.canPublish,
    required this.onAdd,required this.onImport,required this.onSubmit,required this.onPublish,
    required this.onEdit,required this.onDiscard});
  @override
  State<VocabularyWorkspace> createState()=>_VocabularyWorkspaceState();
}
class _VocabularyWorkspaceState extends State<VocabularyWorkspace> {
  String _search='',_stage='all',_status='all',_media='all';
  final _searchController=TextEditingController();
  @override
  void dispose(){_searchController.dispose();super.dispose();}

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);
    final dark=theme.brightness==Brightness.dark;
    final accent=dark?const Color(0xFFA7D9B9):const Color(0xFF245B43);
    final r=VocabularyReadiness.fromRows(widget.items);
    final rows=filterVocabularyWorkspace(widget.items,search:_search,stage:_stage,status:_status,media:_media);
    Widget metric(String label,int count,int total)=>SizedBox(width:145,child:Card(
      elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$count / $total',style:theme.textTheme.titleLarge?.copyWith(color:accent,fontWeight:FontWeight.bold)),
        Text(label,style:theme.textTheme.bodySmall),
      ]))));
    Widget filter(String label,String value,Map<String,String> choices,ValueChanged<String> set)=>SizedBox(width:170,
      child:DropdownButtonFormField<String>(value:value,isExpanded:true,
        decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),
        items:choices.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v){if(v!=null)setState(()=>set(v));}));
    return CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Learning workspace',style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold,color:accent)),
        const SizedBox(height:4),
        const Text('Test1 • Prepare, preview and review language content.'),
        const SizedBox(height:12),
        Wrap(spacing:6,runSpacing:6,children:[
          metric('Classified',r.classified,r.total),metric('Image links',r.images,r.total),metric('Audio links',r.audio,r.total),
          metric('Drafts',r.drafts,r.total),metric('Pending approval',r.pending,r.total),
        ]),
        const Text('Link counts measure availability, not verified media quality. Images are optional where not useful.'),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton.icon(onPressed:widget.onAdd,icon:const Icon(Icons.add),label:const Text('New draft')),
          OutlinedButton.icon(onPressed:widget.onImport,icon:const Icon(Icons.upload_file),label:const Text('Import')),
          OutlinedButton.icon(onPressed:r.drafts==0?null:widget.onSubmit,icon:const Icon(Icons.fact_check_outlined),label:const Text('Submit drafts')),
          if(widget.canPublish) OutlinedButton.icon(onPressed:r.pending==0||r.drafts>0?null:widget.onPublish,icon:const Icon(Icons.publish),label:const Text('Publish on Test1')),
        ]),
        const SizedBox(height:16),
        TextField(controller:_searchController,onChanged:(v)=>setState(()=>_search=v),
          decoration:InputDecoration(labelText:'Search words, meanings, examples or slugs',prefixIcon:const Icon(Icons.search),
            border:const OutlineInputBorder(),suffixIcon:_search.isEmpty?null:IconButton(tooltip:'Clear search',icon:const Icon(Icons.clear),onPressed:(){_searchController.clear();setState(()=>_search='');}))),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          filter('Stage',_stage,{'all':'All stages','easy':'Beginner','medium':'Intermediate','hard':'Advanced','unassigned':'Unassigned'},(v)=>_stage=v),
          filter('Review status',_status,{'all':'All statuses','published':'Published','draft':'Draft','pending_approval':'Pending approval'},(v)=>_status=v),
          filter('Media',_media,{'all':'All media','missing_audio':'Missing audio','missing_image':'Missing image','both_linked':'Both linked'},(v)=>_media=v),
        ]),
        const SizedBox(height:12),
        Text('${rows.length} of ${r.total} cards',style:theme.textTheme.titleSmall),
      ]))),
      if(rows.isEmpty) SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(24),child:Center(
        child:Text(widget.items.isEmpty?'No cards yet. Create or import a draft.':'No cards match your filters.'))))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(12,0,12,24),sliver:SliverList(
        delegate:SliverChildBuilderDelegate((context,i){
          final row=rows[i];
          final canDiscard=workspaceStatus(row)!='published';
          return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(row.term,style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
              const SizedBox(height:4),Text(row.definition,maxLines:3,overflow:TextOverflow.ellipsis),
              const SizedBox(height:8),
              Wrap(spacing:8,runSpacing:4,children:[
                Text(workspaceStage(row.difficulty),style:TextStyle(color:accent,fontWeight:FontWeight.w600)),
                Text(workspaceStatusLabel(row)),
                Text('Position ${row.position}'),
                Text(workspaceHasLink(row.imageUrl)?'Image linked':'No image'),
                Text(workspaceHasLink(row.audioUrl)?'Audio linked':'No audio'),
              ]),
              const SizedBox(height:8),
              Wrap(spacing:4,runSpacing:4,children:[
                TextButton.icon(onPressed:()=>showVocabularyPreview(context,row),icon:const Icon(Icons.visibility_outlined),label:const Text('Preview')),
                TextButton.icon(onPressed:()=>widget.onEdit(row),icon:const Icon(Icons.edit_outlined),label:const Text('Edit draft')),
                if(canDiscard) TextButton.icon(onPressed:()=>widget.onDiscard(row),icon:const Icon(Icons.delete_outline),label:const Text('Discard revision')),
              ]),
            ],
          )));
        },childCount:rows.length),
      )),
    ]);
  }
}

Future<void> showVocabularyPreview(BuildContext context,LessonVocabulary row,{bool unsaved=false}) =>
  showDialog<void>(context:context,builder:(_)=>_VocabularyPreview(row:row,unsaved:unsaved));
class _VocabularyPreview extends StatefulWidget {
  final LessonVocabulary row;
  final bool unsaved;
  const _VocabularyPreview({required this.row,required this.unsaved});
  @override
  State<_VocabularyPreview> createState()=>_VocabularyPreviewState();
}
class _VocabularyPreviewState extends State<_VocabularyPreview> {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  bool _busy=false,_playing=false,_failed=false;
  Future<void> _toggle() async {
    if(_busy)return;
    setState((){_busy=true;_failed=false;});
    try {
      if(_playing){await _player?.stop();if(mounted)setState(()=>_playing=false);}
      else {
        if(_player==null){
          _player=AudioPlayer();
          _completion=_player!.onPlayerComplete.listen((_){if(mounted)setState(()=>_playing=false);});
        }
        if(mounted)setState(()=>_playing=true);
        await _player!.play(UrlSource(widget.row.audioUrl!.trim()));
      }
    }catch(_){if(mounted)setState((){_playing=false;_failed=true;});}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  void dispose(){_completion?.cancel();_player?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    final row=widget.row;
    final dark=Theme.of(context).brightness==Brightness.dark;
    final surface=dark?const Color(0xFF23362F):const Color(0xFFF6F4ED);
    final ink=dark?const Color(0xFFF0F6F2):const Color(0xFF18372C);
    return AlertDialog(
      title:Text(widget.unsaved?'Unsaved learner preview':'Learner preview'),
      content: SizedBox(width:440,child:SingleChildScrollView(child:Container(
        padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(16)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
          Text('${workspaceStage(row.difficulty)} · ${workspaceStatusLabel(row)}',style:TextStyle(color:ink)),
          const SizedBox(height:6),Text(workspaceObjective(row.difficulty),style:TextStyle(color:ink)),
          const SizedBox(height:12),
          if(workspaceHasLink(row.imageUrl)) AspectRatio(aspectRatio:4/3,child:CachedNetworkImage(
            imageUrl:row.imageUrl!.trim(),fit:BoxFit.contain,
            placeholder:(_,__)=>const Center(child:CircularProgressIndicator()),
            errorWidget:(_,__,___)=>const Center(child:Text('Image unavailable'))))
          else Text('No image attached',style:TextStyle(color:ink)),
          const SizedBox(height:12),
          Text(row.term,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold,color:ink)),
          if(row.pronunciation?.trim().isNotEmpty==true) Text(row.pronunciation!,style:TextStyle(fontStyle:FontStyle.italic,color:ink)),
          const SizedBox(height:8),Text(row.definition,style:TextStyle(fontSize:17,color:ink)),
          if(workspaceHasLink(row.audioUrl)) OutlinedButton.icon(onPressed:_busy?null:_toggle,
            icon:Icon(_playing?Icons.stop_circle_outlined:Icons.volume_up_outlined),label:Text(_playing?'Stop audio':'Listen to pronunciation'))
          else Text('Audio not available',style:TextStyle(color:ink)),
          if(_failed) const Text('Could not play audio. Tap to retry.'),
          if(row.example?.trim().isNotEmpty==true)...[const SizedBox(height:12),Text(row.example!,style:TextStyle(color:ink))],
          const SizedBox(height:10),Text('Slug: ${row.fileSlug??"Assigned when saved"}',style:TextStyle(fontSize:12,color:ink)),
        ]),
      ))),
      actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('Close'))],
    );
  }
}
