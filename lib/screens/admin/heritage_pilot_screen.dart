import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/heritage_mission_manifest.dart';
import 'package:kohntri_os_hq/services/xlsx_reader.dart';
export 'package:kohntri_os_hq/models/heritage_mission_manifest.dart';

const _required=['id','title','objective','story','lesson_ids','question_ids','sources'];
const _lists=['lesson_ids','question_ids','sources'];
const _credits=['image_credit','image_license','audio_credit','audio_license'];
const _reviews=['facts_approved','rights_approved','checks_approved'];
bool _filled(Map<String,dynamic> s,String k)=>(s[k]??'').toString().trim().isNotEmpty;
/// Stable, ASCII filenames. Reject unsupported extensions; never guess media type.
String normalizeMissionFilename(String input){
  final name=input.trim().toLowerCase();
  final dot=name.lastIndexOf('.');
  if(dot<=0)throw const FormatException('Choose an image or MP3 with a file extension.');
  final ext=name.substring(dot+1);
  if(!['png','jpg','jpeg','webp','mp3'].contains(ext))throw const FormatException('Use PNG, JPG, JPEG, WebP or MP3.');
  final slug=name.substring(0,dot).replaceAll(RegExp(r'[^a-z0-9]+'),'_').replaceAll(RegExp(r'^_+|_+s.split('|').map((v)=>v.trim()).where((v)=>v.isNotEmpty).toList();

/// Quoted cells, multiline stories and escaped quotes; CSV or tab-delimited TXT.
List<List<String>> parseMissionText(String text) {
  text=text.replaceFirst('\uFEFF','').replaceAll('\r\n','\n').replaceAll('\r','\n');
  final delimiter=text.split('\n').first.contains('\t')?'\t':',';
  final rows=<List<String>>[];
  var row=<String>[];
  var field=StringBuffer();
  var quoted=false;
  for(var i=0;i<text.length;i++){
    final c=text[i];
    if(c=='"'){
      if(quoted&&i+1<text.length&&text[i+1]=='"'){field.write('"');i++;}
      else{quoted=!quoted;}
    }else if(!quoted&&(c==delimiter||c=='\n')){
      row.add(field.toString().trim());field=StringBuffer();
      if(c=='\n'){if(row.any((v)=>v.isNotEmpty))rows.add(row);row=<String>[];}
    }else{field.write(c);}
  }
  if(quoted)throw const FormatException('Unclosed quoted cell.');
  row.add(field.toString().trim());
  if(row.any((v)=>v.isNotEmpty))rows.add(row);
  return rows;
}
void _validateStop(Map<String,dynamic> s){
  final id=s['id'].toString();
  if(!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id)||id.length>80)throw FormatException('Invalid stop ID: $id');
  for(final k in ['title','objective','story']){if(!_filled(s,k))throw FormatException('$id: $k required.');}
  if((s['hook']??'').toString().length>140)throw FormatException('$id: discovery hook must be 140 characters or less.');
  for(final k in _lists){
    final values=List<String>.from(s[k] as List);
    if(values.isEmpty||values.toSet().length!=values.length)throw FormatException('$id: $k must contain distinct references.');
    if(k=='sources'){
      for(final v in values){final u=Uri.tryParse(v);if(u==null||u.scheme!='https'||u.host.isEmpty)throw FormatException('$id: invalid source.');}
    }else if(values.any((v)=>!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v))){throw FormatException('$id: invalid reference UUID.');}
  }
}
/// Merge by stable ID, preserving existing attachments. Changed rows require
/// review again. No imported approval flags are trusted.
List<Map<String,dynamic>> mergeMissionRows(List<List<String>> rows,List<Map<String,dynamic>> current){
  if(rows.length<2)throw const FormatException('Header and at least one stop required.');
  final headers=rows.first.map((v)=>v.trim().toLowerCase()).toList();
  if(headers.toSet().length!=headers.length||_required.any((k)=>!headers.contains(k)))throw const FormatException('Required columns: id, title, objective, story, lesson_ids, question_ids, sources.');
  final merged=[for(final s in current)Map<String,dynamic>.of(s)];
  final seen=<String>{};
  for(var i=1;i<rows.length;i++){
    final cells=rows[i];
    if(cells.every((v)=>v.trim().isEmpty))continue;
    String read(String k){final n=headers.indexOf(k);return n<0||n>=cells.length?'':cells[n].trim();}
    final id=read('id');
    if(!seen.add(id))throw FormatException('Duplicate stop: $id');
    final at=merged.indexWhere((s)=>s['id']==id);
    final previous=at<0?<String,dynamic>{}:merged[at];
    final next=<String,dynamic>{...previous,'id':id,
      for(final k in ['title','objective','story'])k:read(k),
      for(final k in _lists)k:_values(read(k)),
      if(headers.contains('hook'))'hook':read('hook'),
      for(final k in _credits)if(read(k).isNotEmpty)k:read(k)};
    _validateStop(next);
    if(at<0||[..._required,'hook',..._credits].any((k)=>jsonEncode(previous[k])!=jsonEncode(next[k]))){
      for(final k in _reviews){next[k]=false;}
    }
    if(at<0){merged.add(next);}else{merged[at]=next;}
  }
  if(merged.isEmpty||merged.length>50)throw const FormatException('Use 1–50 stops.');
  return merged;
}

class HeritagePilotScreen extends StatefulWidget {
  const HeritagePilotScreen({super.key});
  @override State<HeritagePilotScreen> createState()=>_HeritagePilotScreenState();
}
class _HeritagePilotScreenState extends State<HeritagePilotScreen>{
  final _db=Supabase.instance.client;
  final _title=TextEditingController(text:'Monuments & Relics');
  List<Map<String,dynamic>> _stops=[];
  List<Map<String,dynamic>> _history=[];
  Map<String,dynamic>? _record;
  bool _busy=true,_failed=false,_dirty=false,_canPublish=false;
  String? _error;
  String _search='',_filter='All';
  final _thumbs=<String,Future<String>>{};
  final _expanded=<String>{};
  bool _readyStop(Map<String,dynamic> s)=>_reviews.every((k)=>s[k]==true)&&_filled(s,'image_path')&&_filled(s,'image_credit')&&_filled(s,'image_license')&&(!_filled(s,'audio_path')||(_filled(s,'audio_credit')&&_filled(s,'audio_license')));
  bool _visible(Map<String,dynamic> s)=>(s['title'].toString()+' '+s['id'].toString()).toLowerCase().contains(_search.toLowerCase())&&(_filter=='All'||(_filter=='Needs review'&&!_readyStop(s))||(_filter=='Missing image'&&!_filled(s,'image_path'))||(_filter=='Missing audio'&&!_filled(s,'audio_path'))||(_filter=='Ready'&&_readyStop(s)));
  Future<String> _thumbnail(String path)=>_thumbs.putIfAbsent(path,()=>_db.storage.from('mission_assets_v2').createSignedUrl(path,600));
  String get _status=>_record?['status']?.toString()??'local';
  bool get _editable=>!_failed&&(_status=='local'||_status=='draft');
  int get _ready=>_stops.where((s)=>_reviews.every((k)=>s[k]==true)&&_filled(s,'image_path')&&_filled(s,'image_credit')&&_filled(s,'image_license')&&(!_filled(s,'audio_path')||(_filled(s,'audio_credit')&&_filled(s,'audio_license')))).length;
  @override void initState(){super.initState();_load();}
  @override void dispose(){_title.dispose();super.dispose();}
  Future<dynamic> _rpc(String action,{Map<String,dynamic>? manifest,int? expected,int? revision}) async =>
    await _db.rpc('v2_mission_action',params:{'p_action':action,'p_id':heritageMissionId,if(manifest!=null)'p_manifest':manifest,if(expected!=null)'p_expected':expected,if(revision!=null)'p_revision':revision});
  List<Map<String,dynamic>> _seed()=>[
    for(final s in heritageStops){'id':s.id,'title':s.title,'objective':s.objective,'story':s.story,'lesson_ids':s.lessonIds,'question_ids':s.questionIds,'sources':s.sources,for(final k in _reviews)k:false}
  ];
  void _adopt(dynamic r){
    _record=r==null?null:Map<String,dynamic>.from(r as Map);
    final m=_record?['manifest'] as Map?;
    _title.text=m?['title']?.toString()??'Monuments & Relics';
    _stops=m==null?_seed():[for(final s in m['stops'] as List)Map<String,dynamic>.from(s as Map)];
    _dirty=false;
    _thumbs.clear();
  }
  Future<void> _load()async{
    if(!mounted)return;
    setState((){_busy=true;_failed=false;_error=null;});
    try{
      if(await _db.rpc('is_active_admin')!=true)throw StateError('Active administrator required.');
      final can=await _db.rpc('is_super_admin')==true;
      final r=await _rpc('get_preview');
      final history=await _rpc('history') as List;
      if(!mounted)return;
      setState((){_canPublish=can;_adopt(r);_history=[for(final h in history)Map<String,dynamic>.from(h as Map)];});
    }catch(e){if(mounted)setState((){_failed=true;_error=e.toString();});}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<bool> _confirm(String title,String body)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(body),actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirm'))
  ]))==true;
  Future<void> _run(Future<void> Function() fn)async{
    if(_busy)return;setState((){_busy=true;_error=null;});
    try{await fn();}catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _save()=>_run(()async{
    if(_title.text.trim().isEmpty)throw const FormatException('Mission title required.');
    for(final s in _stops){_validateStop(s);}
    final r=await _rpc('save',manifest:{'title':_title.text.trim(),'stops':_stops},expected:(_record?['edit_token'] as int?)??0,revision:_record?['revision'] as int?);
    if(mounted)setState(()=>_adopt(r));
  });
  Future<void> _transition(String action)async{
    if(!await _confirm('$action mission?',action=='publish'?'Publish this revision to Test1 only.':'Apply $action to the saved Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc(action,expected:_record?['edit_token'] as int?,revision:_record?['revision'] as int?);if(mounted)await _load();});
  }
  Future<void> _import()=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['csv','txt','xlsx']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024)throw const FormatException('Maximum import size 5 MB.');
    List<List<String>> rows;
    if(file.name.toLowerCase().endsWith('.xlsx')){
      final sheets=XlsxReader.read(bytes);
      if(sheets.isEmpty)throw const FormatException('No worksheet data.');
      if(!mounted)return;
      final chosen=sheets.length==1?sheets.first:await showDialog<XlsxSheet>(context:context,builder:(c)=>SimpleDialog(title:const Text('Choose worksheet'),children:[
        for(final s in sheets)SimpleDialogOption(onPressed:()=>Navigator.pop(c,s),child:Text(s.name))
      ]));
      if(chosen==null)return;rows=chosen.rows;
    }else{rows=parseMissionText(utf8.decode(bytes));}
    final next=mergeMissionRows(rows,_stops);
    if(!mounted)return;
    if(!await _confirm('Review import','${rows.length-1} input rows; ${next.length} total stops. Changed rows require review. Nothing is written until Save draft.'))return;
    if(mounted)setState((){_stops=next;_dirty=true;});
  });
  Future<void> _edit(int i)async{
    final s=Map<String,dynamic>.of(_stops[i]);
    final keys=['title','objective','hook','story',..._lists,..._credits];
    final fields={for(final k in keys)k:TextEditingController(text:s[k] is List?(s[k] as List).join('|'):(s[k]??'').toString())};
    final result=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(s['id'].toString()),content:SizedBox(width:540,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final k in keys)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:fields[k],maxLines:k=='story'?5:1,decoration:InputDecoration(labelText:k=='hook'?'Discovery hook (optional)':k,helperText:_lists.contains(k)?'Separate values with |':k=='hook'?'A short question or curiosity-led headline':null)))
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Apply'))]));
    try{
      if(result!=true||!mounted)return;
      for(final k in keys){s[k]=_lists.contains(k)?_values(fields[k]!.text):fields[k]!.text.trim();}
      _validateStop(s);for(final k in _reviews){s[k]=false;}
      setState((){_stops[i]=s;_dirty=true;});
    }catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{for(final c in fields.values){c.dispose();}}
  }
  Future<void> _attach(int i,bool audio)=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:audio?const ['mp3']:const ['png','jpg','jpeg','webp']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;
    await _uploadMedia(i,file.name,await file.readAsBytes(),audio);
  });
  Future<void> _uploadMedia(int i,String filename,Uint8List bytes,bool audio)async{
    final name=normalizeMissionFilename(filename);
    if(audio!=name.endsWith('.mp3'))throw const FormatException('Choose the correct media type.');
    final mime=audio?'audio/mpeg':name.endsWith('.png')?'image/png':name.endsWith('.webp')?'image/webp':'image/jpeg';
    if(bytes.length<12||bytes.length>15*1024*1024)throw const FormatException('Invalid media size; maximum 15 MB.');
    final valid=audio?((bytes[0]==73&&bytes[1]==68&&bytes[2]==51)||(bytes[0]==255&&(bytes[1]&224)==224)):mime=='image/png'?listEquals(bytes.sublist(0,8),[137,80,78,71,13,10,26,10]):mime=='image/webp'?String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&String.fromCharCodes(bytes.sublist(8,12))=='WEBP':bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    if(!valid)throw const FormatException('Invalid media signature.');
    final path='$heritageMissionId/${_stops[i]['id']}/$name';
    final store=_db.storage.from('mission_assets_v2');
    try{await store.uploadBinary(path,bytes,fileOptions:FileOptions(contentType:mime,upsert:false));}
    on StorageException catch(e){if(e.statusCode!='409'&&e.statusCode!='400')rethrow;final existing=await store.download(path);if(!listEquals(existing,bytes))throw StateError('Different file already exists. Use a new versioned filename.');}
    if(mounted)setState((){
      final key=audio?'audio_path':'image_path';
      if(_stops[i][key]!=path){
        _stops[i][key]=path;
        _stops[i][audio?'audio_credit':'image_credit']='';
        _stops[i][audio?'audio_license':'image_license']='';
        _stops[i]['rights_approved']=false;
        _dirty=true;
      }
    });
  }
  Future<void> _bulkMedia()=>_run(()async{
    final files=await FilePicker.pickFiles(allowMultiple:true,type:FileType.custom,allowedExtensions:const ['png','jpg','jpeg','webp','mp3']);
    if(files.isEmpty||!mounted)return;
    final matches=<int,int>{};
    final destinations=<String,List<int>>{};
    final skipped=<String>[];
    for(var n=0;n<files.length;n++){
      final file=files[n];
      try{
        final name=normalizeMissionFilename(file.name);
        final i=matchMissionMedia(name,_stops);
        if(i==null){skipped.add('${file.name}: no unique stop match');continue;}
        final key='$i:${name.endsWith('.mp3')}';
        destinations.putIfAbsent(key,()=>[]).add(n);
        matches[n]=i;
      }catch(_){skipped.add('${file.name}: unsupported filename');}
    }
    for(final group in destinations.values.where((g)=>g.length>1)){
      for(final n in group){matches.remove(n);skipped.add('${files[n].name}: multiple files for the same stop and type');}
    }
    if(!mounted)return;
    final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text('Review media • ${matches.length} matched'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        const Text('Exact stop ID/title matches only. Existing attachments may be replaced; new media requires fresh rights review.'),
        for(final e in matches.entries)ListTile(dense:true,title:Text(files[e.key].name),subtitle:Text('→ ${_stops[e.value]['title']}')),
        if(skipped.isNotEmpty)Text('${skipped.length} skipped',style:Theme.of(c).textTheme.titleMedium),
        for(final reason in skipped)Text(reason),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:matches.isEmpty?null:()=>Navigator.pop(c,true),child:const Text('Attach matched files'))],
    ));
    if(accepted!=true||!mounted)return;
    var success=0;
    final failures=<String>[];
    for(final e in matches.entries){
      if(!mounted)return;
      final file=files[e.key];
      try{await _uploadMedia(e.value,file.name,await file.readAsBytes(),normalizeMissionFilename(file.name).endsWith('.mp3'));success++;}
      catch(error){failures.add('${file.name}: $error');}
    }
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(
      title:Text('$success attached • ${failures.length} failed'),
      content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Save draft to deliver the successful attachments to QA.'),
        for(final reason in [...skipped,...failures])Text(reason),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Done'))],
    ));
  });
  Future<void> _rollback()async{
    final archived=_history.where((r)=>r['status']=='archived').toList();
    final chosen=await showDialog<int>(context:context,builder:(c)=>SimpleDialog(title:const Text('Restore archived revision'),children:[
      for(final r in archived)SimpleDialogOption(onPressed:()=>Navigator.pop(c,r['revision'] as int),child:Text('Revision ${r['revision']}'))
    ]));
    if(chosen==null||!mounted||!await _confirm('Restore revision $chosen?','Creates a new published Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc('rollback',revision:chosen,expected:_record?['revision'] as int?);if(mounted)await _load();});
  }
  Widget _metric(String label,int value)=>Chip(label:Text('$label  $value',style:const TextStyle(fontWeight:FontWeight.w600)));
  Widget _mediaThumb(Map<String,dynamic> stop){
    if(!_filled(stop,'image_path'))return const SizedBox(width:48,height:48,child:Icon(Icons.landscape_outlined));
    final path=stop['image_path'].toString();
    return SizedBox(width:48,height:48,child:ClipRRect(borderRadius:BorderRadius.circular(8),child:FutureBuilder<String>(
      future:_thumbnail(path),builder:(context,snapshot)=>snapshot.hasData?Image.network(snapshot.data!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)):const Icon(Icons.image_outlined),
    )));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Content Studio'),actions:[
      IconButton(tooltip:'Refresh',onPressed:_busy?null:()async{if(!_dirty||await _confirm('Discard local changes?','Unsaved edits will be lost.')){if(mounted)await _load();}},icon:const Icon(Icons.refresh))
    ]),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:ListView(padding:const EdgeInsets.all(16),children:[
      if(_busy)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(_failed)TextButton(onPressed:_busy?null:_load,child:const Text('Retry')),
      if(!_failed)...[
        Text('Test1 • $_status${_record==null?'':' · revision ${_record!['revision']}'}${_dirty?' · unsaved':''}'),
        TextField(controller:_title,enabled:_editable&&!_busy,onChanged:(_)=>setState(()=>_dirty=true),decoration:const InputDecoration(labelText:'Mission title')),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          _metric('Stops',_stops.length),
          _metric('Images',_stops.where((s)=>_filled(s,'image_path')).length),
          _metric('Audio',_stops.where((s)=>_filled(s,'audio_path')).length),
          _metric('Ready',_ready),
        ]),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          if(_editable)OutlinedButton.icon(onPressed:_busy?null:_import,icon:const Icon(Icons.upload_file),label:const Text('Import CSV / TXT / XLSX')),
          if(_editable)OutlinedButton.icon(onPressed:_busy?null:_bulkMedia,icon:const Icon(Icons.collections_outlined),label:const Text('Bulk media')),
          if(_editable)FilledButton(onPressed:_busy||(!_dirty&&_record!=null)?null:_save,child:const Text('Save draft')),
          if(_status=='draft')OutlinedButton(onPressed:_busy||_dirty||_ready!=_stops.length?null:()=>_transition('submit'),child:const Text('Submit')),
          if(_status=='submitted')OutlinedButton(onPressed:_busy?null:()=>_transition('reopen'),child:const Text('Reopen')),
          if(_status=='submitted'&&_canPublish)FilledButton(onPressed:_busy?null:()=>_transition('publish'),child:const Text('Publish on Test1')),
          if(_status=='draft'||_status=='submitted')TextButton(onPressed:_busy?null:()=>_transition('discard'),child:const Text('Discard')),
          if(_status=='published')FilledButton(onPressed:_busy?null:()=>setState((){_record=null;_dirty=true;}),child:const Text('New draft')),
          if(_status=='published'&&_canPublish&&_history.any((r)=>r['status']=='archived'))TextButton(onPressed:_busy?null:_rollback,child:const Text('Restore revision')),
        ]),
        const SizedBox(height:8),
        ExpansionTile(title:const Text('Import format and media matching'),tilePadding:EdgeInsets.zero,children:const [
          Padding(padding:EdgeInsets.all(8),child:Text('Import columns: id, title, objective, story, lesson_ids, question_ids, sources. Optional: hook, media credits and licenses. Separate references with |. Existing IDs merge; new IDs append. Name media after the stop ID or title (e.g. cotton_tree.png). Review matches and save before submitting.')),
        ]),
        TextField(onChanged:(v)=>setState(()=>_search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search discoveries',border:OutlineInputBorder())),
        const SizedBox(height:8),
        Wrap(spacing:6,children:[for(final filter in ['All','Needs review','Missing image','Missing audio','Ready'])ChoiceChip(label:Text(filter),selected:_filter==filter,onSelected:(_)=>setState(()=>_filter=filter))]),
        if(!_stops.any(_visible))const Padding(padding:EdgeInsets.all(16),child:Text('No matching discoveries.')),
        for(var i=0;i<_stops.length;i++)if(_visible(_stops[i]))Card(child:ExpansionTile(
          key:ValueKey(_stops[i]['id']),initiallyExpanded:_expanded.contains(_stops[i]['id']),
          onExpansionChanged:(v)=>setState(()=>v?_expanded.add(_stops[i]['id'].toString()):_expanded.remove(_stops[i]['id'].toString())),
          leading:_mediaThumb(_stops[i]),
          title:Text('${i+1}. ${_stops[i]['title']}'),
          subtitle:Text('${_filled(_stops[i],'image_path')?'Image ✓':'Image —'} · ${_filled(_stops[i],'audio_path')?'Audio ✓':'Audio —'} · ${_readyStop(_stops[i])?'Ready':'Review pending'}'),
          children:[Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_stops[i]['objective'].toString()),if(_filled(_stops[i],'hook'))Text(_stops[i]['hook'].toString(),style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),Text(_stops[i]['story'].toString()),
          Text('Lessons: ${(_stops[i]['lesson_ids'] as List).length} · Checks: ${(_stops[i]['question_ids'] as List).length}'),
          for(final source in _stops[i]['sources'] as List)SelectableText(source.toString(),style:Theme.of(context).textTheme.bodySmall),
          if(_filled(_stops[i],'image_path'))Text('Image: ${_stops[i]['image_path']}'),
          if(_filled(_stops[i],'audio_path'))Text('Audio: ${_stops[i]['audio_path']}'),
          Wrap(spacing:6,children:[for(final k in _reviews)FilterChip(label:Text(k.replaceAll('_approved','')),selected:_stops[i][k]==true,onSelected:!_editable||_busy?null:(v)=>setState((){_stops[i][k]=v;_dirty=true;}))]),
          if(_editable)Wrap(spacing:6,children:[
            TextButton(onPressed:_busy?null:()=>_edit(i),child:const Text('Edit / credit')),
            TextButton(onPressed:_busy?null:()=>_attach(i,false),child:const Text('Attach image')),
            TextButton(onPressed:_busy?null:()=>_attach(i,true),child:const Text('Attach MP3')),
            IconButton(tooltip:'Move up',onPressed:_busy||i==0?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i-1,s);_dirty=true;}),icon:const Icon(Icons.arrow_upward)),
            IconButton(tooltip:'Move down',onPressed:_busy||i==_stops.length-1?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i+1,s);_dirty=true;}),icon:const Icon(Icons.arrow_downward)),
            TextButton(onPressed:_busy||_stops.length==1?null:()async{if(await _confirm('Remove stop?','The saved revision remains unchanged until you save.')){if(mounted)setState((){_stops.removeAt(i);_dirty=true;});}},child:const Text('Remove')),
          ]),
        ]))])),
      ]
    ]))))); 
}
),'');
  if(slug.isEmpty||slug.length>160)throw const FormatException('Filename needs 1–160 ASCII letters or digits.');
  return '$slug.$ext';
}
String _mediaKey(String value)=>value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_').replaceAll(RegExp(r'^_+|_+s.split('|').map((v)=>v.trim()).where((v)=>v.isNotEmpty).toList();

/// Quoted cells, multiline stories and escaped quotes; CSV or tab-delimited TXT.
List<List<String>> parseMissionText(String text) {
  text=text.replaceFirst('\uFEFF','').replaceAll('\r\n','\n').replaceAll('\r','\n');
  final delimiter=text.split('\n').first.contains('\t')?'\t':',';
  final rows=<List<String>>[];
  var row=<String>[];
  var field=StringBuffer();
  var quoted=false;
  for(var i=0;i<text.length;i++){
    final c=text[i];
    if(c=='"'){
      if(quoted&&i+1<text.length&&text[i+1]=='"'){field.write('"');i++;}
      else{quoted=!quoted;}
    }else if(!quoted&&(c==delimiter||c=='\n')){
      row.add(field.toString().trim());field=StringBuffer();
      if(c=='\n'){if(row.any((v)=>v.isNotEmpty))rows.add(row);row=<String>[];}
    }else{field.write(c);}
  }
  if(quoted)throw const FormatException('Unclosed quoted cell.');
  row.add(field.toString().trim());
  if(row.any((v)=>v.isNotEmpty))rows.add(row);
  return rows;
}
void _validateStop(Map<String,dynamic> s){
  final id=s['id'].toString();
  if(!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id)||id.length>80)throw FormatException('Invalid stop ID: $id');
  for(final k in ['title','objective','story']){if(!_filled(s,k))throw FormatException('$id: $k required.');}
  for(final k in _lists){
    final values=List<String>.from(s[k] as List);
    if(values.isEmpty||values.toSet().length!=values.length)throw FormatException('$id: $k must contain distinct references.');
    if(k=='sources'){
      for(final v in values){final u=Uri.tryParse(v);if(u==null||u.scheme!='https'||u.host.isEmpty)throw FormatException('$id: invalid source.');}
    }else if(values.any((v)=>!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v))){throw FormatException('$id: invalid reference UUID.');}
  }
}
/// Merge by stable ID, preserving existing attachments. Changed rows require
/// review again. No imported approval flags are trusted.
List<Map<String,dynamic>> mergeMissionRows(List<List<String>> rows,List<Map<String,dynamic>> current){
  if(rows.length<2)throw const FormatException('Header and at least one stop required.');
  final headers=rows.first.map((v)=>v.trim().toLowerCase()).toList();
  if(headers.toSet().length!=headers.length||_required.any((k)=>!headers.contains(k)))throw const FormatException('Required columns: id, title, objective, story, lesson_ids, question_ids, sources.');
  final merged=[for(final s in current)Map<String,dynamic>.of(s)];
  final seen=<String>{};
  for(var i=1;i<rows.length;i++){
    final cells=rows[i];
    if(cells.every((v)=>v.trim().isEmpty))continue;
    String read(String k){final n=headers.indexOf(k);return n<0||n>=cells.length?'':cells[n].trim();}
    final id=read('id');
    if(!seen.add(id))throw FormatException('Duplicate stop: $id');
    final at=merged.indexWhere((s)=>s['id']==id);
    final previous=at<0?<String,dynamic>{}:merged[at];
    final next=<String,dynamic>{...previous,'id':id,
      for(final k in ['title','objective','story'])k:read(k),
      for(final k in _lists)k:_values(read(k)),
      for(final k in _credits)if(read(k).isNotEmpty)k:read(k)};
    _validateStop(next);
    if(at<0||[..._required,..._credits].any((k)=>jsonEncode(previous[k])!=jsonEncode(next[k]))){
      for(final k in _reviews){next[k]=false;}
    }
    if(at<0){merged.add(next);}else{merged[at]=next;}
  }
  if(merged.isEmpty||merged.length>50)throw const FormatException('Use 1–50 stops.');
  return merged;
}

class HeritagePilotScreen extends StatefulWidget {
  const HeritagePilotScreen({super.key});
  @override State<HeritagePilotScreen> createState()=>_HeritagePilotScreenState();
}
class _HeritagePilotScreenState extends State<HeritagePilotScreen>{
  final _db=Supabase.instance.client;
  final _title=TextEditingController(text:'Monuments & Relics');
  List<Map<String,dynamic>> _stops=[];
  List<Map<String,dynamic>> _history=[];
  Map<String,dynamic>? _record;
  bool _busy=true,_failed=false,_dirty=false,_canPublish=false;
  String? _error;
  String get _status=>_record?['status']?.toString()??'local';
  bool get _editable=>!_failed&&(_status=='local'||_status=='draft');
  int get _ready=>_stops.where((s)=>_reviews.every((k)=>s[k]==true)&&_filled(s,'image_path')&&_filled(s,'image_credit')&&_filled(s,'image_license')&&(!_filled(s,'audio_path')||(_filled(s,'audio_credit')&&_filled(s,'audio_license')))).length;
  @override void initState(){super.initState();_load();}
  @override void dispose(){_title.dispose();super.dispose();}
  Future<dynamic> _rpc(String action,{Map<String,dynamic>? manifest,int? expected,int? revision}) async =>
    await _db.rpc('v2_mission_action',params:{'p_action':action,'p_id':heritageMissionId,if(manifest!=null)'p_manifest':manifest,if(expected!=null)'p_expected':expected,if(revision!=null)'p_revision':revision});
  List<Map<String,dynamic>> _seed()=>[
    for(final s in heritageStops){'id':s.id,'title':s.title,'objective':s.objective,'story':s.story,'lesson_ids':s.lessonIds,'question_ids':s.questionIds,'sources':s.sources,for(final k in _reviews)k:false}
  ];
  void _adopt(dynamic r){
    _record=r==null?null:Map<String,dynamic>.from(r as Map);
    final m=_record?['manifest'] as Map?;
    _title.text=m?['title']?.toString()??'Monuments & Relics';
    _stops=m==null?_seed():[for(final s in m['stops'] as List)Map<String,dynamic>.from(s as Map)];
    _dirty=false;
  }
  Future<void> _load()async{
    if(!mounted)return;
    setState((){_busy=true;_failed=false;_error=null;});
    try{
      if(await _db.rpc('is_active_admin')!=true)throw StateError('Active administrator required.');
      final can=await _db.rpc('is_super_admin')==true;
      final r=await _rpc('get_preview');
      final history=await _rpc('history') as List;
      if(!mounted)return;
      setState((){_canPublish=can;_adopt(r);_history=[for(final h in history)Map<String,dynamic>.from(h as Map)];});
    }catch(e){if(mounted)setState((){_failed=true;_error=e.toString();});}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<bool> _confirm(String title,String body)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(body),actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirm'))
  ]))==true;
  Future<void> _run(Future<void> Function() fn)async{
    if(_busy)return;setState((){_busy=true;_error=null;});
    try{await fn();}catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _save()=>_run(()async{
    if(_title.text.trim().isEmpty)throw const FormatException('Mission title required.');
    for(final s in _stops){_validateStop(s);}
    final r=await _rpc('save',manifest:{'title':_title.text.trim(),'stops':_stops},expected:(_record?['edit_token'] as int?)??0,revision:_record?['revision'] as int?);
    if(mounted)setState(()=>_adopt(r));
  });
  Future<void> _transition(String action)async{
    if(!await _confirm('$action mission?',action=='publish'?'Publish this revision to Test1 only.':'Apply $action to the saved Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc(action,expected:_record?['edit_token'] as int?,revision:_record?['revision'] as int?);if(mounted)await _load();});
  }
  Future<void> _import()=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['csv','txt','xlsx']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024)throw const FormatException('Maximum import size 5 MB.');
    List<List<String>> rows;
    if(file.name.toLowerCase().endsWith('.xlsx')){
      final sheets=XlsxReader.read(bytes);
      if(sheets.isEmpty)throw const FormatException('No worksheet data.');
      if(!mounted)return;
      final chosen=sheets.length==1?sheets.first:await showDialog<XlsxSheet>(context:context,builder:(c)=>SimpleDialog(title:const Text('Choose worksheet'),children:[
        for(final s in sheets)SimpleDialogOption(onPressed:()=>Navigator.pop(c,s),child:Text(s.name))
      ]));
      if(chosen==null)return;rows=chosen.rows;
    }else{rows=parseMissionText(utf8.decode(bytes));}
    final next=mergeMissionRows(rows,_stops);
    if(!mounted)return;
    if(!await _confirm('Review import','${rows.length-1} input rows; ${next.length} total stops. Changed rows require review. Nothing is written until Save draft.'))return;
    if(mounted)setState((){_stops=next;_dirty=true;});
  });
  Future<void> _edit(int i)async{
    final s=Map<String,dynamic>.of(_stops[i]);
    final keys=['title','objective','story',..._lists,..._credits];
    final fields={for(final k in keys)k:TextEditingController(text:s[k] is List?(s[k] as List).join('|'):(s[k]??'').toString())};
    final result=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(s['id'].toString()),content:SizedBox(width:540,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final k in keys)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:fields[k],maxLines:k=='story'?5:1,decoration:InputDecoration(labelText:k,helperText:_lists.contains(k)?'Separate values with |':null)))
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Apply'))]));
    try{
      if(result!=true||!mounted)return;
      for(final k in keys){s[k]=_lists.contains(k)?_values(fields[k]!.text):fields[k]!.text.trim();}
      _validateStop(s);for(final k in _reviews){s[k]=false;}
      setState((){_stops[i]=s;_dirty=true;});
    }catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{for(final c in fields.values){c.dispose();}}
  }
  Future<void> _attach(int i,bool audio)=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:audio?const ['mp3']:const ['png','jpg','jpeg','webp']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;final bytes=await file.readAsBytes();final name=file.name.toLowerCase();
    if(!RegExp(audio?r'^[a-z0-9]+(_[a-z0-9]+)*\.mp3$':r'^[a-z0-9]+(_[a-z0-9]+)*\.(png|jpg|jpeg|webp)$').hasMatch(name))throw const FormatException('Use lowercase underscore-separated filenames.');
    final mime=audio?'audio/mpeg':name.endsWith('.png')?'image/png':name.endsWith('.webp')?'image/webp':'image/jpeg';
    if(bytes.length<12||bytes.length>15*1024*1024)throw const FormatException('Invalid media size; maximum 15 MB.');
    final valid=audio?((bytes[0]==73&&bytes[1]==68&&bytes[2]==51)||(bytes[0]==255&&(bytes[1]&224)==224)):mime=='image/png'?listEquals(bytes.sublist(0,8),[137,80,78,71,13,10,26,10]):mime=='image/webp'?String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&String.fromCharCodes(bytes.sublist(8,12))=='WEBP':bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    if(!valid)throw const FormatException('Invalid media signature.');
    final path='$heritageMissionId/${_stops[i]['id']}/$name';
    final store=_db.storage.from('mission_assets_v2');
    try{await store.uploadBinary(path,Uint8List.fromList(bytes),fileOptions:FileOptions(contentType:mime,upsert:false));}
    on StorageException catch(e){if(e.statusCode!='409'&&e.statusCode!='400')rethrow;final existing=await store.download(path);if(!listEquals(existing,bytes))throw StateError('Different file already exists. Use a new versioned filename.');}
    if(mounted)setState((){_stops[i][audio?'audio_path':'image_path']=path;_stops[i]['rights_approved']=false;_dirty=true;});
  });
  Future<void> _rollback()async{
    final archived=_history.where((r)=>r['status']=='archived').toList();
    final chosen=await showDialog<int>(context:context,builder:(c)=>SimpleDialog(title:const Text('Restore archived revision'),children:[
      for(final r in archived)SimpleDialogOption(onPressed:()=>Navigator.pop(c,r['revision'] as int),child:Text('Revision ${r['revision']}'))
    ]));
    if(chosen==null||!mounted||!await _confirm('Restore revision $chosen?','Creates a new published Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc('rollback',revision:chosen,expected:_record?['revision'] as int?);if(mounted)await _load();});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Mission workspace'),actions:[
      IconButton(tooltip:'Refresh',onPressed:_busy?null:()async{if(!_dirty||await _confirm('Discard local changes?','Unsaved edits will be lost.')){if(mounted)await _load();}},icon:const Icon(Icons.refresh))
    ]),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:ListView(padding:const EdgeInsets.all(16),children:[
      if(_busy)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(_failed)TextButton(onPressed:_busy?null:_load,child:const Text('Retry')),
      if(!_failed)...[
        Text('Test1 • $_status${_record==null?'':' · revision ${_record!['revision']}'}${_dirty?' · unsaved':''}'),
        TextField(controller:_title,enabled:_editable&&!_busy,onChanged:(_)=>setState(()=>_dirty=true),decoration:const InputDecoration(labelText:'Mission title')),
        const SizedBox(height:12),Text('$_ready/${_stops.length} stops ready'),
        Wrap(spacing:8,runSpacing:8,children:[
          if(_editable)OutlinedButton.icon(onPressed:_busy?null:_import,icon:const Icon(Icons.upload_file),label:const Text('Import CSV / TXT / XLSX')),
          if(_editable)FilledButton(onPressed:_busy||(!_dirty&&_record!=null)?null:_save,child:const Text('Save draft')),
          if(_status=='draft')OutlinedButton(onPressed:_busy||_dirty||_ready!=_stops.length?null:()=>_transition('submit'),child:const Text('Submit')),
          if(_status=='submitted')OutlinedButton(onPressed:_busy?null:()=>_transition('reopen'),child:const Text('Reopen')),
          if(_status=='submitted'&&_canPublish)FilledButton(onPressed:_busy?null:()=>_transition('publish'),child:const Text('Publish on Test1')),
          if(_status=='draft'||_status=='submitted')TextButton(onPressed:_busy?null:()=>_transition('discard'),child:const Text('Discard')),
          if(_status=='published')FilledButton(onPressed:_busy?null:()=>setState((){_record=null;_dirty=true;}),child:const Text('New draft')),
          if(_status=='published'&&_canPublish&&_history.any((r)=>r['status']=='archived'))TextButton(onPressed:_busy?null:_rollback,child:const Text('Restore revision')),
        ]),
        const SizedBox(height:8),
        const Text('Import columns: id, title, objective, story, lesson_ids, question_ids, sources. Separate references with |. Existing IDs merge; new IDs append. Save before submitting.'),
        for(var i=0;i<_stops.length;i++)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${i+1}. ${_stops[i]['title']}',style:Theme.of(context).textTheme.titleLarge),
          Text(_stops[i]['objective'].toString()),const SizedBox(height:6),Text(_stops[i]['story'].toString()),
          Text('Lessons: ${(_stops[i]['lesson_ids'] as List).length} · Checks: ${(_stops[i]['question_ids'] as List).length}'),
          for(final source in _stops[i]['sources'] as List)SelectableText(source.toString(),style:Theme.of(context).textTheme.bodySmall),
          if(_filled(_stops[i],'image_path'))Text('Image: ${_stops[i]['image_path']}'),
          if(_filled(_stops[i],'audio_path'))Text('Audio: ${_stops[i]['audio_path']}'),
          Wrap(spacing:6,children:[for(final k in _reviews)FilterChip(label:Text(k.replaceAll('_approved','')),selected:_stops[i][k]==true,onSelected:!_editable||_busy?null:(v)=>setState((){_stops[i][k]=v;_dirty=true;}))]),
          if(_editable)Wrap(spacing:6,children:[
            TextButton(onPressed:_busy?null:()=>_edit(i),child:const Text('Edit / credit')),
            TextButton(onPressed:_busy?null:()=>_attach(i,false),child:const Text('Attach image')),
            TextButton(onPressed:_busy?null:()=>_attach(i,true),child:const Text('Attach MP3')),
            IconButton(tooltip:'Move up',onPressed:_busy||i==0?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i-1,s);_dirty=true;}),icon:const Icon(Icons.arrow_upward)),
            IconButton(tooltip:'Move down',onPressed:_busy||i==_stops.length-1?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i+1,s);_dirty=true;}),icon:const Icon(Icons.arrow_downward)),
            TextButton(onPressed:_busy||_stops.length==1?null:()async{if(await _confirm('Remove stop?','The saved revision remains unchanged until you save.')){if(mounted)setState((){_stops.removeAt(i);_dirty=true;});}},child:const Text('Remove')),
          ]),
        ]))),
      ]
    ]))))); 
}
),'');
/// Only exact, unambiguous stop IDs or titles may be auto-matched.
int? matchMissionMedia(String filename,List<Map<String,dynamic>> stops){
  final name=normalizeMissionFilename(filename);
  final key=name.substring(0,name.lastIndexOf('.'));
  final matches=<int>[for(var i=0;i<stops.length;i++)if(key==_mediaKey(stops[i]['id'].toString())||key==_mediaKey(stops[i]['title'].toString()))i];
  return matches.length==1?matches.single:null;
}
List<String> _values(String s)=>s.split('|').map((v)=>v.trim()).where((v)=>v.isNotEmpty).toList();

/// Quoted cells, multiline stories and escaped quotes; CSV or tab-delimited TXT.
List<List<String>> parseMissionText(String text) {
  text=text.replaceFirst('\uFEFF','').replaceAll('\r\n','\n').replaceAll('\r','\n');
  final delimiter=text.split('\n').first.contains('\t')?'\t':',';
  final rows=<List<String>>[];
  var row=<String>[];
  var field=StringBuffer();
  var quoted=false;
  for(var i=0;i<text.length;i++){
    final c=text[i];
    if(c=='"'){
      if(quoted&&i+1<text.length&&text[i+1]=='"'){field.write('"');i++;}
      else{quoted=!quoted;}
    }else if(!quoted&&(c==delimiter||c=='\n')){
      row.add(field.toString().trim());field=StringBuffer();
      if(c=='\n'){if(row.any((v)=>v.isNotEmpty))rows.add(row);row=<String>[];}
    }else{field.write(c);}
  }
  if(quoted)throw const FormatException('Unclosed quoted cell.');
  row.add(field.toString().trim());
  if(row.any((v)=>v.isNotEmpty))rows.add(row);
  return rows;
}
void _validateStop(Map<String,dynamic> s){
  final id=s['id'].toString();
  if(!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id)||id.length>80)throw FormatException('Invalid stop ID: $id');
  for(final k in ['title','objective','story']){if(!_filled(s,k))throw FormatException('$id: $k required.');}
  for(final k in _lists){
    final values=List<String>.from(s[k] as List);
    if(values.isEmpty||values.toSet().length!=values.length)throw FormatException('$id: $k must contain distinct references.');
    if(k=='sources'){
      for(final v in values){final u=Uri.tryParse(v);if(u==null||u.scheme!='https'||u.host.isEmpty)throw FormatException('$id: invalid source.');}
    }else if(values.any((v)=>!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v))){throw FormatException('$id: invalid reference UUID.');}
  }
}
/// Merge by stable ID, preserving existing attachments. Changed rows require
/// review again. No imported approval flags are trusted.
List<Map<String,dynamic>> mergeMissionRows(List<List<String>> rows,List<Map<String,dynamic>> current){
  if(rows.length<2)throw const FormatException('Header and at least one stop required.');
  final headers=rows.first.map((v)=>v.trim().toLowerCase()).toList();
  if(headers.toSet().length!=headers.length||_required.any((k)=>!headers.contains(k)))throw const FormatException('Required columns: id, title, objective, story, lesson_ids, question_ids, sources.');
  final merged=[for(final s in current)Map<String,dynamic>.of(s)];
  final seen=<String>{};
  for(var i=1;i<rows.length;i++){
    final cells=rows[i];
    if(cells.every((v)=>v.trim().isEmpty))continue;
    String read(String k){final n=headers.indexOf(k);return n<0||n>=cells.length?'':cells[n].trim();}
    final id=read('id');
    if(!seen.add(id))throw FormatException('Duplicate stop: $id');
    final at=merged.indexWhere((s)=>s['id']==id);
    final previous=at<0?<String,dynamic>{}:merged[at];
    final next=<String,dynamic>{...previous,'id':id,
      for(final k in ['title','objective','story'])k:read(k),
      for(final k in _lists)k:_values(read(k)),
      for(final k in _credits)if(read(k).isNotEmpty)k:read(k)};
    _validateStop(next);
    if(at<0||[..._required,..._credits].any((k)=>jsonEncode(previous[k])!=jsonEncode(next[k]))){
      for(final k in _reviews){next[k]=false;}
    }
    if(at<0){merged.add(next);}else{merged[at]=next;}
  }
  if(merged.isEmpty||merged.length>50)throw const FormatException('Use 1–50 stops.');
  return merged;
}

class HeritagePilotScreen extends StatefulWidget {
  const HeritagePilotScreen({super.key});
  @override State<HeritagePilotScreen> createState()=>_HeritagePilotScreenState();
}
class _HeritagePilotScreenState extends State<HeritagePilotScreen>{
  final _db=Supabase.instance.client;
  final _title=TextEditingController(text:'Monuments & Relics');
  List<Map<String,dynamic>> _stops=[];
  List<Map<String,dynamic>> _history=[];
  Map<String,dynamic>? _record;
  bool _busy=true,_failed=false,_dirty=false,_canPublish=false;
  String? _error;
  String get _status=>_record?['status']?.toString()??'local';
  bool get _editable=>!_failed&&(_status=='local'||_status=='draft');
  int get _ready=>_stops.where((s)=>_reviews.every((k)=>s[k]==true)&&_filled(s,'image_path')&&_filled(s,'image_credit')&&_filled(s,'image_license')&&(!_filled(s,'audio_path')||(_filled(s,'audio_credit')&&_filled(s,'audio_license')))).length;
  @override void initState(){super.initState();_load();}
  @override void dispose(){_title.dispose();super.dispose();}
  Future<dynamic> _rpc(String action,{Map<String,dynamic>? manifest,int? expected,int? revision}) async =>
    await _db.rpc('v2_mission_action',params:{'p_action':action,'p_id':heritageMissionId,if(manifest!=null)'p_manifest':manifest,if(expected!=null)'p_expected':expected,if(revision!=null)'p_revision':revision});
  List<Map<String,dynamic>> _seed()=>[
    for(final s in heritageStops){'id':s.id,'title':s.title,'objective':s.objective,'story':s.story,'lesson_ids':s.lessonIds,'question_ids':s.questionIds,'sources':s.sources,for(final k in _reviews)k:false}
  ];
  void _adopt(dynamic r){
    _record=r==null?null:Map<String,dynamic>.from(r as Map);
    final m=_record?['manifest'] as Map?;
    _title.text=m?['title']?.toString()??'Monuments & Relics';
    _stops=m==null?_seed():[for(final s in m['stops'] as List)Map<String,dynamic>.from(s as Map)];
    _dirty=false;
  }
  Future<void> _load()async{
    if(!mounted)return;
    setState((){_busy=true;_failed=false;_error=null;});
    try{
      if(await _db.rpc('is_active_admin')!=true)throw StateError('Active administrator required.');
      final can=await _db.rpc('is_super_admin')==true;
      final r=await _rpc('get_preview');
      final history=await _rpc('history') as List;
      if(!mounted)return;
      setState((){_canPublish=can;_adopt(r);_history=[for(final h in history)Map<String,dynamic>.from(h as Map)];});
    }catch(e){if(mounted)setState((){_failed=true;_error=e.toString();});}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<bool> _confirm(String title,String body)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(body),actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirm'))
  ]))==true;
  Future<void> _run(Future<void> Function() fn)async{
    if(_busy)return;setState((){_busy=true;_error=null;});
    try{await fn();}catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _save()=>_run(()async{
    if(_title.text.trim().isEmpty)throw const FormatException('Mission title required.');
    for(final s in _stops){_validateStop(s);}
    final r=await _rpc('save',manifest:{'title':_title.text.trim(),'stops':_stops},expected:(_record?['edit_token'] as int?)??0,revision:_record?['revision'] as int?);
    if(mounted)setState(()=>_adopt(r));
  });
  Future<void> _transition(String action)async{
    if(!await _confirm('$action mission?',action=='publish'?'Publish this revision to Test1 only.':'Apply $action to the saved Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc(action,expected:_record?['edit_token'] as int?,revision:_record?['revision'] as int?);if(mounted)await _load();});
  }
  Future<void> _import()=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['csv','txt','xlsx']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024)throw const FormatException('Maximum import size 5 MB.');
    List<List<String>> rows;
    if(file.name.toLowerCase().endsWith('.xlsx')){
      final sheets=XlsxReader.read(bytes);
      if(sheets.isEmpty)throw const FormatException('No worksheet data.');
      if(!mounted)return;
      final chosen=sheets.length==1?sheets.first:await showDialog<XlsxSheet>(context:context,builder:(c)=>SimpleDialog(title:const Text('Choose worksheet'),children:[
        for(final s in sheets)SimpleDialogOption(onPressed:()=>Navigator.pop(c,s),child:Text(s.name))
      ]));
      if(chosen==null)return;rows=chosen.rows;
    }else{rows=parseMissionText(utf8.decode(bytes));}
    final next=mergeMissionRows(rows,_stops);
    if(!mounted)return;
    if(!await _confirm('Review import','${rows.length-1} input rows; ${next.length} total stops. Changed rows require review. Nothing is written until Save draft.'))return;
    if(mounted)setState((){_stops=next;_dirty=true;});
  });
  Future<void> _edit(int i)async{
    final s=Map<String,dynamic>.of(_stops[i]);
    final keys=['title','objective','story',..._lists,..._credits];
    final fields={for(final k in keys)k:TextEditingController(text:s[k] is List?(s[k] as List).join('|'):(s[k]??'').toString())};
    final result=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(s['id'].toString()),content:SizedBox(width:540,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final k in keys)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:fields[k],maxLines:k=='story'?5:1,decoration:InputDecoration(labelText:k,helperText:_lists.contains(k)?'Separate values with |':null)))
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Apply'))]));
    try{
      if(result!=true||!mounted)return;
      for(final k in keys){s[k]=_lists.contains(k)?_values(fields[k]!.text):fields[k]!.text.trim();}
      _validateStop(s);for(final k in _reviews){s[k]=false;}
      setState((){_stops[i]=s;_dirty=true;});
    }catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{for(final c in fields.values){c.dispose();}}
  }
  Future<void> _attach(int i,bool audio)=>_run(()async{
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:audio?const ['mp3']:const ['png','jpg','jpeg','webp']);
    if(files.isEmpty||!mounted)return;
    final file=files.first;final bytes=await file.readAsBytes();final name=file.name.toLowerCase();
    if(!RegExp(audio?r'^[a-z0-9]+(_[a-z0-9]+)*\.mp3$':r'^[a-z0-9]+(_[a-z0-9]+)*\.(png|jpg|jpeg|webp)$').hasMatch(name))throw const FormatException('Use lowercase underscore-separated filenames.');
    final mime=audio?'audio/mpeg':name.endsWith('.png')?'image/png':name.endsWith('.webp')?'image/webp':'image/jpeg';
    if(bytes.length<12||bytes.length>15*1024*1024)throw const FormatException('Invalid media size; maximum 15 MB.');
    final valid=audio?((bytes[0]==73&&bytes[1]==68&&bytes[2]==51)||(bytes[0]==255&&(bytes[1]&224)==224)):mime=='image/png'?listEquals(bytes.sublist(0,8),[137,80,78,71,13,10,26,10]):mime=='image/webp'?String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&String.fromCharCodes(bytes.sublist(8,12))=='WEBP':bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    if(!valid)throw const FormatException('Invalid media signature.');
    final path='$heritageMissionId/${_stops[i]['id']}/$name';
    final store=_db.storage.from('mission_assets_v2');
    try{await store.uploadBinary(path,Uint8List.fromList(bytes),fileOptions:FileOptions(contentType:mime,upsert:false));}
    on StorageException catch(e){if(e.statusCode!='409'&&e.statusCode!='400')rethrow;final existing=await store.download(path);if(!listEquals(existing,bytes))throw StateError('Different file already exists. Use a new versioned filename.');}
    if(mounted)setState((){_stops[i][audio?'audio_path':'image_path']=path;_stops[i]['rights_approved']=false;_dirty=true;});
  });
  Future<void> _rollback()async{
    final archived=_history.where((r)=>r['status']=='archived').toList();
    final chosen=await showDialog<int>(context:context,builder:(c)=>SimpleDialog(title:const Text('Restore archived revision'),children:[
      for(final r in archived)SimpleDialogOption(onPressed:()=>Navigator.pop(c,r['revision'] as int),child:Text('Revision ${r['revision']}'))
    ]));
    if(chosen==null||!mounted||!await _confirm('Restore revision $chosen?','Creates a new published Test1 revision.'))return;
    if(!mounted)return;
    await _run(()async{await _rpc('rollback',revision:chosen,expected:_record?['revision'] as int?);if(mounted)await _load();});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Mission workspace'),actions:[
      IconButton(tooltip:'Refresh',onPressed:_busy?null:()async{if(!_dirty||await _confirm('Discard local changes?','Unsaved edits will be lost.')){if(mounted)await _load();}},icon:const Icon(Icons.refresh))
    ]),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:ListView(padding:const EdgeInsets.all(16),children:[
      if(_busy)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(_failed)TextButton(onPressed:_busy?null:_load,child:const Text('Retry')),
      if(!_failed)...[
        Text('Test1 • $_status${_record==null?'':' · revision ${_record!['revision']}'}${_dirty?' · unsaved':''}'),
        TextField(controller:_title,enabled:_editable&&!_busy,onChanged:(_)=>setState(()=>_dirty=true),decoration:const InputDecoration(labelText:'Mission title')),
        const SizedBox(height:12),Text('$_ready/${_stops.length} stops ready'),
        Wrap(spacing:8,runSpacing:8,children:[
          if(_editable)OutlinedButton.icon(onPressed:_busy?null:_import,icon:const Icon(Icons.upload_file),label:const Text('Import CSV / TXT / XLSX')),
          if(_editable)FilledButton(onPressed:_busy||(!_dirty&&_record!=null)?null:_save,child:const Text('Save draft')),
          if(_status=='draft')OutlinedButton(onPressed:_busy||_dirty||_ready!=_stops.length?null:()=>_transition('submit'),child:const Text('Submit')),
          if(_status=='submitted')OutlinedButton(onPressed:_busy?null:()=>_transition('reopen'),child:const Text('Reopen')),
          if(_status=='submitted'&&_canPublish)FilledButton(onPressed:_busy?null:()=>_transition('publish'),child:const Text('Publish on Test1')),
          if(_status=='draft'||_status=='submitted')TextButton(onPressed:_busy?null:()=>_transition('discard'),child:const Text('Discard')),
          if(_status=='published')FilledButton(onPressed:_busy?null:()=>setState((){_record=null;_dirty=true;}),child:const Text('New draft')),
          if(_status=='published'&&_canPublish&&_history.any((r)=>r['status']=='archived'))TextButton(onPressed:_busy?null:_rollback,child:const Text('Restore revision')),
        ]),
        const SizedBox(height:8),
        const Text('Import columns: id, title, objective, story, lesson_ids, question_ids, sources. Separate references with |. Existing IDs merge; new IDs append. Save before submitting.'),
        for(var i=0;i<_stops.length;i++)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${i+1}. ${_stops[i]['title']}',style:Theme.of(context).textTheme.titleLarge),
          Text(_stops[i]['objective'].toString()),const SizedBox(height:6),Text(_stops[i]['story'].toString()),
          Text('Lessons: ${(_stops[i]['lesson_ids'] as List).length} · Checks: ${(_stops[i]['question_ids'] as List).length}'),
          for(final source in _stops[i]['sources'] as List)SelectableText(source.toString(),style:Theme.of(context).textTheme.bodySmall),
          if(_filled(_stops[i],'image_path'))Text('Image: ${_stops[i]['image_path']}'),
          if(_filled(_stops[i],'audio_path'))Text('Audio: ${_stops[i]['audio_path']}'),
          Wrap(spacing:6,children:[for(final k in _reviews)FilterChip(label:Text(k.replaceAll('_approved','')),selected:_stops[i][k]==true,onSelected:!_editable||_busy?null:(v)=>setState((){_stops[i][k]=v;_dirty=true;}))]),
          if(_editable)Wrap(spacing:6,children:[
            TextButton(onPressed:_busy?null:()=>_edit(i),child:const Text('Edit / credit')),
            TextButton(onPressed:_busy?null:()=>_attach(i,false),child:const Text('Attach image')),
            TextButton(onPressed:_busy?null:()=>_attach(i,true),child:const Text('Attach MP3')),
            IconButton(tooltip:'Move up',onPressed:_busy||i==0?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i-1,s);_dirty=true;}),icon:const Icon(Icons.arrow_upward)),
            IconButton(tooltip:'Move down',onPressed:_busy||i==_stops.length-1?null:()=>setState((){final s=_stops.removeAt(i);_stops.insert(i+1,s);_dirty=true;}),icon:const Icon(Icons.arrow_downward)),
            TextButton(onPressed:_busy||_stops.length==1?null:()async{if(await _confirm('Remove stop?','The saved revision remains unchanged until you save.')){if(mounted)setState((){_stops.removeAt(i);_dirty=true;});}},child:const Text('Remove')),
          ]),
        ]))),
      ]
    ]))))); 
}
