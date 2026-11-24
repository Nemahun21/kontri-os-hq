import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'vocabulary_fast_upload_view.dart';
import '../../widgets/content_workspace_metrics.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/lesson_vocab_service.dart';

import 'package:kohntri_os_hq/screens/admin/vocabulary_bulk_import_screen.dart';

class LessonVocabularyManagementScreen extends StatefulWidget {
  final String contentType; // 'adventure' or 'language'
  final String? category; // Adventure only
  final String? themeId; // Language only
  final String title;

  const LessonVocabularyManagementScreen({
    super.key,
    required this.contentType,
    this.category,
    this.themeId,
    required this.title,
  });

  @override
  State<LessonVocabularyManagementScreen> createState() =>
      _LessonVocabularyManagementScreenState();
}

class _LessonVocabularyManagementScreenState
    extends State<LessonVocabularyManagementScreen> {
  final LessonVocabularyService _service = LessonVocabularyService();
  List<LessonVocabulary> _items = [];
  bool _isLoading = true;

  String _selectedDifficulty = 'easy';
  String _search = '', _mediaFilter = 'all';
  String? _loadError, _playingId;
  final _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSub;

  bool get _isAdventure => widget.contentType == 'adventure';
  bool get _isLanguage => widget.contentType == 'language';

  @override
  void initState() {
    super.initState();
    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if(mounted) setState(()=>_playingId=null);
    });
    _load();
  }

  @override
  void dispose() { _completeSub?.cancel(); _audioPlayer.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final items = await _service.getVocabulary(
        contentType: widget.contentType,
        category: _isAdventure ? widget.category : null,
        themeId: _isLanguage ? widget.themeId : null,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadError=e.toString(); _isLoading=false; });
    }
  }

  static bool _linked(String? url)=>url!=null&&url.trim().isNotEmpty;
  List<LessonVocabulary> get _scopedItems => _isLanguage?_items:_items.where((i)=>i.difficulty==_selectedDifficulty).toList();
  List<LessonVocabulary> get _filteredItems {
    final q=_search.toLowerCase();
    return _scopedItems.where((i){
      final image=_linked(i.imageUrl),audio=_linked(i.audioUrl);
      final text='${i.term} ${i.definition} ${i.pronunciation??""} ${i.example??""}'.toLowerCase();
      return text.contains(q) && (_mediaFilter=='all'||(_mediaFilter=='image'&&!image)||
        (_mediaFilter=='audio'&&!audio)||(_mediaFilter=='complete'&&image&&audio));
    }).toList();
  }
  Future<void> _openStudio({LessonVocabulary? item}) async {
    await _audioPlayer.stop();
    if(!mounted)return;
    setState(()=>_playingId=null);
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>VocabularyFastUploadView(
      initialThemeId:widget.themeId,existing:item)));
    if(mounted) await _load();
  }
  void _addItem() { if(_isLanguage) { _openStudio(); } else { _showEditor(); } }
  void _editItem(LessonVocabulary item) { if(_isLanguage) { _openStudio(item:item); } else { _showEditor(item:item); } }
  Future<void> _play(LessonVocabulary item) async {
    try {
      await _audioPlayer.stop();
      if(!mounted)return;
      if(_playingId==item.id){setState(()=>_playingId=null);return;}
      setState(()=>_playingId=item.id);
      await _audioPlayer.play(UrlSource(item.audioUrl!));
    } catch(e) {
      if(mounted){setState(()=>_playingId=null);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Playback failed: $e')));}
    }
  }

  Future<void> _deleteItem(LessonVocabulary item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item.term}"? The vocabulary record will be removed; its media files remain available for reuse.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try { await _service.delete(item.id); if(mounted) await _load(); }
      catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Delete failed: $e'))); }
    }
  }

  Future<void> _showEditor({LessonVocabulary? item}) async {
    final isEdit = item != null;
    final termController = TextEditingController(text: item?.term ?? '');
    final definitionController = TextEditingController(
      text: item?.definition ?? '',
    );
    final pronunciationController = TextEditingController(
      text: item?.pronunciation ?? '',
    );
    final exampleController = TextEditingController(text: item?.example ?? '');
    final emojiController = TextEditingController(text: item?.emoji ?? '');
    // final positionController =
    //     TextEditingController(text: (item?.position ?? 1).toString());
    final imageUrlController = TextEditingController(
      text: item?.imageUrl ?? '',
    );

    final audioUrlController = TextEditingController(text: item?.audioUrl ?? '');
    // Only for Adventure
    String difficulty = item?.difficulty ?? _selectedDifficulty;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Vocabulary' : 'Add Vocabulary'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Difficulty dropdown – ADVENTURE ONLY
                  if (_isAdventure) ...[
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('💡 Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('🔥 Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('🌊 Hard')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => difficulty = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: emojiController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji (optional)',
                      hintText: 'e.g., 👋',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termController,
                    decoration: InputDecoration(
                      labelText: _isLanguage ? 'Word' : 'Term',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: definitionController,
                    decoration: InputDecoration(
                      labelText: _isLanguage ? 'Translation' : 'Definition',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_isLanguage) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pronunciationController,
                      decoration: const InputDecoration(
                        labelText: 'Pronunciation (optional)',
                        hintText: 'e.g., koo-sheh',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: exampleController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Example / Context (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: audioUrlController,
                    decoration: const InputDecoration(labelText: 'Audio URL (optional)', border: OutlineInputBorder()),
                  ),
                  if (item?.fileSlug != null) SelectableText('Asset key: '+item!.fileSlug!),
                  // const SizedBox(height: 12),
                  // TextField(
                  //   controller: positionController,
                  //   keyboardType: TextInputType.number,
                  //   decoration: const InputDecoration(
                  //     labelText: 'Position',
                  //     border: OutlineInputBorder(),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Safety: for language, themeId MUST exist
                if (_isLanguage && widget.themeId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Theme ID is missing. Cannot save.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                int position;
                if (isEdit && item != null) {
                  position = item.position;
                } else {
                  // Find the highest position in the current filtered list, add 1
                  final siblings = _items
                      .where(
                        (i) =>
                            (_isAdventure && i.difficulty == difficulty) ||
                            (_isLanguage),
                      )
                      .toList();

                  if (siblings.isEmpty) {
                    position = 1;
                  } else {
                    final maxPos = siblings
                        .map((i) => i.position)
                        .reduce((a, b) => a > b ? a : b);
                    position = maxPos + 1;
                  }
                }

                final vocab = LessonVocabulary(
                  id: item?.id ?? '',
                  contentType: widget.contentType,
                  // Adventure: category + difficulty, Language: themeId only
                  category: _isAdventure ? widget.category : null,
                  themeId: _isLanguage ? widget.themeId : null,
                  difficulty: _isAdventure ? difficulty : null,
                  term: termController.text.trim(),
                  definition: definitionController.text.trim(),
                  pronunciation: pronunciationController.text.trim().isEmpty
                      ? null
                      : pronunciationController.text.trim(),
                  example: exampleController.text.trim().isEmpty
                      ? null
                      : exampleController.text.trim(),
                  emoji: emojiController.text.trim().isEmpty
                      ? null
                      : emojiController.text.trim(),
                  fileSlug: item?.fileSlug,
                  audioUrl: audioUrlController.text.trim().isEmpty ? null : audioUrlController.text.trim(),
                  imageUrl: imageUrlController.text.trim().isEmpty
                      ? null
                      : imageUrlController.text.trim(),
                  position: position,
                );

                if (isEdit) {
                  await _service.update(vocab);
                } else {
                  await _service.add(vocab);
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
            if (isEdit && item != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Position: ${item.position}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (result == true) _load();
  }

  Future<void> _importFromFile() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VocabularyBulkImportScreen(
        contentType: widget.contentType,
        initialThemeId: widget.themeId,
        initialCategory: widget.category,
        initialDifficulty: _selectedDifficulty,
      ),
    ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scoped=_scopedItems,items=_filteredItems;
    final images=scoped.where((i)=>_linked(i.imageUrl)).length;
    final audio=scoped.where((i)=>_linked(i.audioUrl)).length;
    final complete=scoped.where((i)=>_linked(i.imageUrl)&&_linked(i.audioUrl)).length;
    return Scaffold(
      appBar:AppBar(title:Text('Lesson Cards: ${widget.title}'),actions:[
        IconButton(onPressed:_isLoading?null:_importFromFile,icon:const Icon(Icons.upload_file),tooltip:'Bulk import'),
        IconButton(onPressed:_isLoading?null:_load,icon:const Icon(Icons.refresh),tooltip:'Refresh'),
      ]),
      body:_isLoading?const Center(child:CircularProgressIndicator()):Column(children:[
        if(_loadError!=null) Padding(padding:const EdgeInsets.all(12),child:Text('Load failed: $_loadError',style:TextStyle(color:Theme.of(context).colorScheme.error))),
        Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
          if(_isAdventure) Wrap(spacing:8,children:[
            for(final d in ['easy','medium','hard']) ChoiceChip(label:Text(d),selected:_selectedDifficulty==d,
              onSelected:(_)=>setState(()=>_selectedDifficulty=d)),
          ]),
          WorkspaceMetrics(values:{'Vocabulary':_loadError==null?'${scoped.length}':'—','Images':_loadError==null?'$images':'—','Recordings':_loadError==null?'$audio':'—','Missing media':_loadError==null?'${scoped.length-complete}':'—'}),
          const SizedBox(height:14),
          Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
            FilledButton.icon(onPressed:_loadError==null?_addItem:null,icon:const Icon(Icons.add),label:const Text('Add vocabulary')),
            OutlinedButton.icon(onPressed:_importFromFile,icon:const Icon(Icons.upload_file),label:const Text('Bulk import')),
            for(final f in {'all':'All','image':'Missing image','audio':'Missing audio','complete':'Complete media'}.entries)
              ChoiceChip(label:Text(f.value),selected:_mediaFilter==f.key,onSelected:(_)=>setState(()=>_mediaFilter=f.key)),
          ]),
          const SizedBox(height:12),
          TextField(onChanged:(v)=>setState(()=>_search=v.trim()),decoration:const InputDecoration(
            prefixIcon:Icon(Icons.search),hintText:'Search term, meaning, pronunciation…',border:OutlineInputBorder())),
          const SizedBox(height:12),
          Text('${items.length} of ${scoped.length} records',style:Theme.of(context).textTheme.bodySmall),
          const SizedBox(height:8),
          if(items.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No matching vocabulary.')))
          else LayoutBuilder(builder:(context,constraints){
            if(constraints.maxWidth<800) return Column(children:[for(final item in items) _compact(item)]);
            return _table(items);
          }),
        ])),
      ]),
    );
  }

  Widget _thumbnail(LessonVocabulary item) {
    final fallback=Center(child:Text(item.emoji?.isNotEmpty==true?item.emoji!:'—',style:const TextStyle(fontSize:18)));
    return SizedBox(width:42,height:42,child:Material(color:Theme.of(context).colorScheme.surfaceContainerHighest,
      shape:const CircleBorder(),clipBehavior:Clip.antiAlias,
      child:InkWell(onTap:!_linked(item.imageUrl)?null:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text(item.term),content:Image.network(item.imageUrl!,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('Image unavailable')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))])),
        child:_linked(item.imageUrl)?Image.network(item.imageUrl!,fit:BoxFit.contain,errorBuilder:(_,__,___)=>fallback):fallback)));
  }
  Widget _audio(LessonVocabulary item) => IconButton(
    tooltip:!_linked(item.audioUrl)?'No recording':_playingId==item.id?'Stop recording':'Play recording',
    color:_linked(item.audioUrl)?const Color(0xFF18794E):null,
    onPressed:_linked(item.audioUrl)?()=>_play(item):null,
    icon:Icon(!_linked(item.audioUrl)?Icons.volume_off_outlined:_playingId==item.id?Icons.stop_circle_outlined:Icons.volume_up_outlined));
  Widget _actions(LessonVocabulary item)=>Row(mainAxisSize:MainAxisSize.min,children:[
    IconButton(onPressed:_loadError==null?()=>_editItem(item):null,tooltip:'Edit vocabulary',icon:const Icon(Icons.edit_outlined)),
    PopupMenuButton<String>(enabled:_loadError==null,tooltip:'More actions',onSelected:(v){if(v=='delete')_deleteItem(item);},
      itemBuilder:(_)=>const [PopupMenuItem(value:'delete',child:Text('Delete vocabulary…'))]),
  ]);
  Widget _compact(LessonVocabulary item)=>Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(
    children:[
      Row(children:[_thumbnail(item),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(item.term,style:const TextStyle(fontWeight:FontWeight.w600)),Text(item.definition),
        if(item.pronunciation?.isNotEmpty==true)Text(item.pronunciation!),
        if(item.example?.isNotEmpty==true)Text(item.example!,maxLines:2,overflow:TextOverflow.ellipsis),
      ]))]),
      Row(children:[Text('Pos ${item.position}'),const Spacer(),_audio(item),_actions(item)]),
    ])));

  Widget _table(List<LessonVocabulary> items) {
    const headers=['Image','Word','Translation','Pronunciation','Example','Audio','Pos','Actions'];
    const flex=[1,3,3,2,4,1,1,2];
    Widget line(List<Widget> cells,{bool header=false})=>Container(
      decoration:BoxDecoration(color:header?Theme.of(context).colorScheme.surfaceContainerHighest:null,
        border:Border(bottom:BorderSide(color:Theme.of(context).colorScheme.outlineVariant))),
      padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[
        for(var i=0;i<cells.length;i++)
          if(i==0||i==5||i==6||i==7) SizedBox(width:i==7?104:i==6?52:64,child:Center(child:cells[i]))
          else Expanded(flex:flex[i],child:Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:cells[i])),
      ]));
    Widget cell(String? value)=>Text(value??'—',maxLines:2,overflow:TextOverflow.ellipsis);
    return Card(clipBehavior:Clip.antiAlias,child:Column(children:[
      line([for(final h in headers) Text(h,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12))],header:true),
      for(final item in items) line([_thumbnail(item),cell(item.term),cell(item.definition),
        cell(item.pronunciation),cell(item.example),_audio(item),cell('${item.position}'),_actions(item)]),
    ]));
  }
}
