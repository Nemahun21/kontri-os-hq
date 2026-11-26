import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/lesson_vocab_service.dart';
import 'package:kohntri_os_hq/widgets/vocabulary_workspace.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kohntri_os_hq/services/xlsx_reader.dart';

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
  bool _canPublish = false;
  bool _loadFailed = false;

  String _selectedDifficulty = 'easy'; // Existing Adventure filter
  String _languageDifficultyFilter = 'all'; // Never hide words by default

  bool get _isAdventure => widget.contentType == 'adventure';
  bool get _isLanguage => widget.contentType == 'language';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _loadFailed = false; });
    try {
      final items = await _service.getVocabulary(
        contentType: widget.contentType,
        category: _isAdventure ? widget.category : null,
        themeId: _isLanguage ? widget.themeId : null,
      );
      final canPublish = _isLanguage && await _service.canPublish();
      if (!mounted) return;
      setState(() {
        _canPublish = canPublish;
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _loadFailed = true; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  List<LessonVocabulary> get _filteredItems {
    if (_isLanguage) {
      if (_languageDifficultyFilter == 'all') return _items;
      if (_languageDifficultyFilter == 'unassigned') {
        return _items.where((i) => i.difficulty == null).toList();
      }
      return _items.where((i) => i.difficulty == _languageDifficultyFilter).toList();
    }
    return _items.where((i) => i.difficulty == _selectedDifficulty).toList();
  }

  void _addItem() => _showEditor();
  void _editItem(LessonVocabulary item) => _showEditor(item: item);

  Future<void> _deleteItem(LessonVocabulary item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard revision'),
        content: Text('Discard draft for "${item.term}"? Published content will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try { await _service.delete(item.id); await _load(); }
      catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'))); }
    }
  }

  Future<void> _showEditor({LessonVocabulary? item}) async {
    if (!_isLanguage) return;
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
    final positionController = TextEditingController(
      text: (item?.position ?? 1).toString(),
    );
    final imageUrlController = TextEditingController(
      text: item?.imageUrl ?? '',
    );

    final audioUrlController = TextEditingController(text:item?.audioUrl ?? '');
    bool saving = false;
    bool uploading = false;
    String? difficulty = item?.difficulty ?? (_isAdventure ? _selectedDifficulty : null);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit vocabulary draft' : 'New vocabulary draft'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Both content types use the same DB values; language
                  // UI presents them as Beginner / Intermediate / Advanced.
                  ...[
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Beginner / Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Intermediate / Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('Advanced / Hard')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => difficulty = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: Text(workspaceObjective(difficulty))),
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
                  if (item?.fileSlug != null) ...[
                    Text('File slug: ${item!.fileSlug}'),
                    TextButton.icon(onPressed: saving || uploading ? null : () async {
                      setDialogState(() => uploading=true);
                      try {
                        final picked=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['png','jpg','jpeg','webp']);
                        if(picked.isNotEmpty) {
                          final file=picked.first;
                          final url=await _service.uploadAsset(item:item!,filename:file.name,bytes:await file.readAsBytes(),audio:false);
                          if(ctx.mounted) imageUrlController.text=url;
                        }
                      } catch(e) { if(ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e'))); }
                      finally { if(ctx.mounted) setDialogState(()=>uploading=false); }
                    },icon:const Icon(Icons.image),label:const Text('Upload shared image')),
                  ],
                  const SizedBox(height:12),
                  TextField(controller:audioUrlController,decoration:const InputDecoration(labelText:'Audio URL (MP3)',border:OutlineInputBorder())),
                  if(item?.fileSlug != null) TextButton.icon(onPressed:saving||uploading?null:() async {
                    setDialogState(()=>uploading=true);
                    try {
                      final picked=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['mp3']);
                      if(picked.isNotEmpty) {
                        final file=picked.first;
                        final url=await _service.uploadAsset(item:item!,filename:file.name,bytes:await file.readAsBytes(),audio:true);
                        if(ctx.mounted) audioUrlController.text=url;
                      }
                    } catch(e) { if(ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e'))); }
                    finally { if(ctx.mounted) setDialogState(()=>uploading=false); }
                  },icon:const Icon(Icons.audio_file),label:const Text('Upload target-language MP3')),
                  if(item?.fileSlug == null) const Text('Save first, then reopen to attach named assets.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Position within theme',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: saving || uploading ? null : () => showVocabularyPreview(
                ctx,
                LessonVocabulary(
                  id: item?.id ?? '',
                  contentType: widget.contentType,
                  themeId: widget.themeId,
                  term: termController.text.trim(),
                  definition: definitionController.text.trim(),
                  difficulty: difficulty,
                  pronunciation: pronunciationController.text.trim(),
                  example: exampleController.text.trim(),
                  imageUrl: imageUrlController.text.trim(),
                  audioUrl: audioUrlController.text.trim(),
                  fileSlug: item?.fileSlug,
                  status: 'draft',
                ),
                unsaved: true,
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview'),
            ),
            TextButton(
              onPressed: saving || uploading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving || uploading ? null : () async {
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

                if (difficulty == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Choose a difficulty before saving.')),
                  );
                  return;
                }
                final requestedPosition = int.tryParse(positionController.text.trim());
                if (requestedPosition == null || requestedPosition < 1) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Position must be a positive number.')),
                  );
                  return;
                }
                int position;
                if (isEdit && item != null) {
                  position = requestedPosition;
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
                  // New entries default to the next safe sequential position.
                }

                final vocab = LessonVocabulary(
                  id: item?.id ?? '',
                  contentType: widget.contentType,
                  // Difficulty is valid for Adventure and Language.
                  category: _isAdventure ? widget.category : null,
                  themeId: _isLanguage ? widget.themeId : null,
                  difficulty: difficulty,
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
                  imageUrl: imageUrlController.text.trim().isEmpty
                      ? null
                      : imageUrlController.text.trim(),
                  // Existing sound must survive unrelated text edits.
                  audioUrl: _emptyToNull(audioUrlController.text.trim()),
                  fileSlug: item?.fileSlug,
                  position: position,
                );

                setDialogState(()=>saving=true);
                try {
                  if (isEdit) { await _service.update(vocab); } else { await _service.add(vocab); }
                  if(ctx.mounted) Navigator.pop(ctx,true);
                } catch(e) {
                  if(ctx.mounted) {setDialogState(()=>saving=false); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Draft save failed: $e')));}
                }
              },
              child: const Text('Save draft'),
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

    for(final controller in [termController,definitionController,pronunciationController,exampleController,emojiController,positionController,imageUrlController,audioUrlController]) {controller.dispose();}
    if (result == true && mounted) _load();
  }

  Future<void> _importFromFile() async {
  if (!_isLanguage) return;
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt', 'xlsx'],
  );
  if (files.isEmpty) return;

  final file = files.first;
  late List<Map<String, String>> rows;

  try {
    var bytes = await file.readAsBytes();
    final isExcel = file.name.toLowerCase().endsWith('.xlsx');

    if (isExcel) {
      final sheets = XlsxReader.read(bytes);
      if (sheets.isEmpty) {
        throw const FormatException('Excel has no data.');
      }
      var chosen = sheets;
      if (sheets.length > 1 && mounted) {
        final picked = await showDialog<List<XlsxSheet>>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Which sheet?'),
            children: [
              for (final s in sheets)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, [s]),
                  child: Text('${s.name} · ${s.rows.length - 1} rows'),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, sheets),
                child: const Text('All sheets combined'),
              ),
            ],
          ),
        );
        if (picked == null) return;
        chosen = picked;
      }
      bytes = XlsxReader.toCsv(chosen);
    }

    rows = _parseLessonCsv(bytes);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not read file: $e'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (rows.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No data rows found.')),
    );
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import vocabulary drafts'),
      content: Text(
        '${rows.length} rows ready.\n'
        '${_isAdventure ? 'Difficulty: $_selectedDifficulty\n' : ''}'
        'Language rows must include easy/medium/hard difficulty.\n'
        'Empty word/translation rows will be skipped.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Import'),
        ),
      ],
    ),
  );
  if (ok != true || !mounted) return;

  setState(() => _isLoading = true);
  var added = 0;
  var skipped = 0;

  try {
    // Next position among current siblings
    final siblings = _isAdventure
        ? _items.where((i) => i.difficulty == _selectedDifficulty)
        : _items;
    var nextPos = siblings.isEmpty
        ? 1
        : siblings.map((i) => i.position).reduce((a, b) => a > b ? a : b) + 1;

    for (final row in rows) {
      final term = _cell(row, const ['word', 'term']);
      final definition = _cell(row, const ['translation', 'definition']);
      if (term.isEmpty || definition.isEmpty) {
        skipped++;
        continue;
      }

      final difficultyFromFile = _cell(row, const ['difficulty']).toLowerCase();
      final difficulty = _isAdventure
          ? (['easy', 'medium', 'hard'].contains(difficultyFromFile)
              ? difficultyFromFile
              : _selectedDifficulty)
          : ({'beginner': 'easy', 'intermediate': 'medium', 'advanced': 'hard'}[
                  difficultyFromFile] ?? difficultyFromFile);
      if (!['easy', 'medium', 'hard'].contains(difficulty)) {
        skipped++;
        continue; // Never silently import unclassified language vocabulary.
      }

      final posRaw = int.tryParse(_cell(row, const ['position']));
      final position = posRaw ?? nextPos;
      if (posRaw == null) nextPos++;

      final vocab = LessonVocabulary(
        id: '',
        contentType: widget.contentType,
        category: _isAdventure ? widget.category : null,
        themeId: _isLanguage ? widget.themeId : null,
        difficulty: difficulty,
        term: term,
        definition: definition,
        pronunciation: _emptyToNull(_cell(row, const ['pronunciation'])),
        example: _emptyToNull(_cell(row, const ['example'])),
        emoji: _emptyToNull(_cell(row, const ['emoji'])),
        imageUrl: _emptyToNull(_cell(row, const ['image', 'image_url'])),
        audioUrl: _emptyToNull(_cell(row, const ['audio_url'])),
        fileSlug: _emptyToNull(_cell(row, const ['file_slug'])),
        position: position,
      );

      await _service.add(vocab);
      added++;
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import stopped: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  await _load();
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Imported $added · skipped $skipped')),
  );
}

String _cell(Map<String, String> row, List<String> keys) {
  for (final k in keys) {
    for (final e in row.entries) {
      if (e.key.trim().toLowerCase() == k) {
        return e.value.trim();
      }
    }
  }
  return '';
}

String? _emptyToNull(String s) => s.isEmpty ? null : s;
List<Map<String, String>> _parseLessonCsv(Uint8List bytes) {
  var content = utf8.decode(bytes, allowMalformed: true);
  content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (content.startsWith('\uFEFF')) {
    content = content.substring(1);
  }

  final lines = content
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];

  final header = _splitCsvLine(lines.first);
  final rows = <Map<String, String>>[];

  for (var i = 1; i < lines.length; i++) {
    final raw = _splitCsvLine(lines[i]);
    if (raw.every((c) => c.trim().isEmpty)) continue;

    final map = <String, String>{};
    for (var j = 0; j < header.length; j++) {
      final key = header[j].trim();
      if (key.isEmpty) continue;
      map[key] = j < raw.length ? raw[j].trim() : '';
    }
    rows.add(map);
  }
  return rows;
}

/// Handles commas and simple "quoted, fields".
List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      result.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  result.add(buf.toString());
  return result;
}

  Future<void> _reviewTheme(bool publish) async {
    final theme=widget.themeId;
    if(theme==null || _isLoading || (publish && !_canPublish)) return;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(publish?'Publish approved theme on Test1?':'Submit all theme drafts?'),
      content:Text(publish?'This updates staging learner vocabulary only. Verify the QA preview first.':'All current drafts in this theme become pending approval.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(publish?'Publish on Test1':'Submit'))],
    ));
    if(confirmed!=true || !mounted)return;
    setState(()=>_isLoading=true);
    try {
      final n=publish?await _service.publishTheme(theme):await _service.submitTheme(theme);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$n ${publish?'published':'submitted'}')));
    } catch(e) {if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    if(mounted) await _load();
  }

  // ---------------------- BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3498DB);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_isLanguage?'Draft workspace':'Read-only'}: ${widget.title}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if(_isLanguage) IconButton(tooltip:'Submit theme drafts',icon:const Icon(Icons.fact_check),onPressed:_isLoading?null:()=>_reviewTheme(false)),
          if(_isLanguage && _canPublish) IconButton(tooltip:'Publish reviewed theme on Test1',icon:const Icon(Icons.publish),onPressed:_isLoading?null:()=>_reviewTheme(true)),
          if(_isLanguage) IconButton(
  icon: const Icon(Icons.upload_file_rounded),
  tooltip: 'Import CSV / TXT / Excel drafts',
  onPressed: _isLoading ? null : _importFromFile,
),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load the content workspace.'),
                  TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ]))
              : _isLanguage
              ? VocabularyWorkspace(
                  items: _items,
                  canPublish: _canPublish,
                  onAdd: _addItem,
                  onEdit: _editItem,
                  onDiscard: _deleteItem,
                  onImport: _importFromFile,
                  onSubmit: () => _reviewTheme(false),
                  onPublish: () => _reviewTheme(true),
                )
              : Column(
              children: [
                if (_isAdventure) _buildDifficultyTabs(),
                if (_isLanguage) _buildLanguageDifficultyFilters(),
                // Table
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : _buildTable(accent),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageDifficultyFilters() {
    const values = ['all', 'easy', 'medium', 'hard', 'unassigned'];
    const labels = ['All', 'Beginner', 'Intermediate', 'Advanced', 'Unassigned'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(values.length, (i) {
          final value = values[i];
          final count = value == 'all'
              ? _items.length
              : value == 'unassigned'
                  ? _items.where((v) => v.difficulty == null).length
                  : _items.where((v) => v.difficulty == value).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${labels[i]} ($count)'),
              selected: _languageDifficultyFilter == value,
              onSelected: (_) => setState(() => _languageDifficultyFilter = value),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDifficultyTabs() {
    final difficulties = [
      {'key': 'easy', 'label': '💡 Easy', 'color': Colors.green},
      {'key': 'medium', 'label': '🔥 Medium', 'color': Colors.orange},
      {'key': 'hard', 'label': '🌊 Hard', 'color': Colors.blue},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: difficulties.map((d) {
          final key = d['key'] as String;
          final label = d['label'] as String;
          final color = d['color'] as Color;
          final isSelected = _selectedDifficulty == key;
          final count = _items.where((i) => i.difficulty == key).length;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? color : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _isAdventure
                ? 'No $_selectedDifficulty lesson cards yet.'
                : 'No lesson cards yet.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first card.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(Color accent) {
    final items = _filteredItems;

    final List<String> headers;
    final List<int> flexValues;

    if (_isLanguage) {
      headers = [
        'Word',
        'Translation',
        'Pronunciation',
        'Example',
        'Difficulty',
        'Pos',
        'Actions',
      ];
      flexValues = [3, 3, 2, 4, 2, 1, 3];
    } else {
      headers = ['Term', 'Definition', 'Example', 'Pos', 'Actions'];
      flexValues = [3, 4, 4, 1, 3];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: accent.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.style, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isLanguage
                        ? 'Lesson Cards'
                        : '${_selectedDifficulty.toUpperCase()} Lesson Cards',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: List.generate(headers.length, (i) {
                  return Expanded(
                    flex: flexValues[i],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        headers[i],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            ...items.asMap().entries.map((entry) {
              return _buildDataRow(
                index: entry.key,
                item: entry.value,
                flexValues: flexValues,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow({
    required int index,
    required LessonVocabulary item,
    required List<int> flexValues,
  }) {
    final List<Widget> cells = [];

    cells.add(
      Row(
        children: [
          if (item.emoji != null && item.emoji!.isNotEmpty) ...[
            Text(item.emoji!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              '${item.term}${item.status==null?'':' · ${item.status}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    cells.add(
      Text(
        item.definition,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );

    if (_isLanguage) {
      cells.add(
        Text(
          item.pronunciation ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontStyle: item.pronunciation != null
                ? FontStyle.italic
                : FontStyle.normal,
            color: Colors.grey[700],
          ),
        ),
      );
    }

    cells.add(
      Text(
        item.example ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );

    if (_isLanguage) {
      const names = {'easy': 'Beginner', 'medium': 'Intermediate', 'hard': 'Advanced'};
      cells.add(Text(names[item.difficulty] ?? 'Unassigned',
          style: const TextStyle(fontSize: 12)));
    }
    cells.add(Text('${item.position}', style: const TextStyle(fontSize: 12)));

    cells.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _isLanguage ? () => _editItem(item) : null,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              child: const Icon(Icons.edit, color: Colors.blue, size: 16),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isLanguage && (item.status=='draft'||item.status=='pending_approval') ? () => _deleteItem(item) : null,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              child: const Icon(Icons.delete, color: Colors.red, size: 16),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          final isActionColumn = i == cells.length - 1; 
          final child = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: cells[i],
          );

          if (isActionColumn) {
            return SizedBox(
              width: 72,
              child: child,
            ); 
          }

          return Expanded(
            flex: i < flexValues.length ? flexValues[i] : 1,
            child: child,
          );
        }),
      ),
    );
  }
}
