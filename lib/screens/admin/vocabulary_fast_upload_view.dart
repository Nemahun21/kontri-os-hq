import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/vocabulary_draft_controller.dart';
import '../../services/lesson_vocab_service.dart';
import '../../widgets/vocabulary_asset_drop_zone.dart';
import '../../widgets/vocabulary_live_preview.dart';

class VocabularyFastUploadView extends StatefulWidget {
  final String? initialThemeId;
  const VocabularyFastUploadView({super.key, this.initialThemeId});
  @override
  State<VocabularyFastUploadView> createState() => _VocabularyFastUploadViewState();
}
class _VocabularyFastUploadViewState extends State<VocabularyFastUploadView> {
  late final VocabularyDraftController _draft;
  final _term = TextEditingController(), _definition = TextEditingController(),
    _pronunciation = TextEditingController(), _example = TextEditingController(),
    _emoji = TextEditingController();
  final _termFocus = FocusNode();
  List<Map<String, dynamic>> _languages = [], _themes = [];
  String? _languageId;
  bool _loading = true, _confirming = false;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    _draft = VocabularyDraftController(Supabase.instance.client, LessonVocabularyService());
    _loadScopes();
  }
  Future<void> _loadScopes() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final client = Supabase.instance.client;
      Future<List<Map<String,dynamic>>> read(String table, String columns) async {
        final rows = <Map<String,dynamic>>[];
        for (var offset = 0;; offset += 500) {
          final page = await client.from(table).select(columns).order('id').range(offset, offset + 499);
          rows.addAll(List<Map<String,dynamic>>.from(page));
          if (page.length < 500) return rows;
        }
      }
      final data = await Future.wait([
        read('language_type','id,name,code'), read('language_themes','id,language_type_id,name'),
      ]);
      if (!mounted) return;
      _languages = data[0]; _themes = data[1];
      _languages.sort((a,b) => a['name'].toString().compareTo(b['name'].toString()));
      _themes.sort((a,b) => a['name'].toString().compareTo(b['name'].toString()));
      for (final theme in _themes) {
        if (theme['id'].toString() == widget.initialThemeId) {
          _languageId = theme['language_type_id'].toString();
          _draft.selectTheme(widget.initialThemeId, _code); break;
        }
      }
    } catch (e) { if (mounted) _loadError = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  String? get _code {
    for (final l in _languages) {
      if (l['id'].toString() == _languageId) return l['code'].toString();
    }
    return null;
  }
  void _changed() {
    _draft.term = _term.text; _draft.definition = _definition.text;
    _draft.pronunciation = _pronunciation.text; _draft.example = _example.text; _draft.emoji = _emoji.text;
    _draft.schedule();
  }
  @override
  void dispose() {
    _draft.dispose(); _term.dispose(); _definition.dispose(); _pronunciation.dispose();
    _example.dispose(); _emoji.dispose(); _termFocus.dispose(); super.dispose();
  }
  Future<void> _publish() async {
    if (!_draft.canPublish || _confirming) return;
    setState(() => _confirming = true);
    try {
      final approved = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Publish this vocabulary?'),
        content: Text('${_draft.term} — ${_draft.definition}\n'
          '${_draft.sameTerm ? "This term already exists in this theme. Confirm this is a distinct meaning.\n" : ""}'
          '${_draft.allowMissing ? "Missing media is explicitly allowed.\n" : ""}'
          'Existing content and files will not be overwritten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('Publish & Next')),
        ],
      ));
      if (approved != true || !mounted || !_draft.canPublish) return;
      await _draft.publish();
      if (!mounted) return;
      for (final field in [_term,_definition,_pronunciation,_example,_emoji]) { field.clear(); }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vocabulary saved. Ready for next entry.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _termFocus.requestFocus(); });
      }
    }
  }
  Widget _field(String label, TextEditingController controller, bool enabled,
      {FocusNode? focus, int lines = 1, int? maxLength}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, enabled: enabled, focusNode: focus,
      maxLines: lines, maxLength: maxLength, onChanged: (_) => _changed(),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
  Widget _input(bool enabled) {
    final themes = _themes.where((t) => t['language_type_id'].toString() == _languageId).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Vocabulary input', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      InputDecorator(decoration: const InputDecoration(labelText: 'Language'),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          isExpanded: true, value: _languageId, hint: const Text('Select language'),
          items: [for (final l in _languages) DropdownMenuItem(value: l['id'].toString(),
            child: Text(l['name'].toString(), overflow: TextOverflow.ellipsis))],
          onChanged: !enabled ? null : (id) {
            setState(() => _languageId = id); _draft.selectTheme(null, _code);
          },
        ))),
      const SizedBox(height: 10),
      InputDecorator(decoration: const InputDecoration(labelText: 'Theme'),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          isExpanded: true, value: _draft.themeId, hint: const Text('Select theme'),
          items: [for (final t in themes) DropdownMenuItem(value: t['id'].toString(),
            child: Text(t['name'].toString(), overflow: TextOverflow.ellipsis))],
          onChanged: !enabled || _languageId == null ? null : (id) => _draft.selectTheme(id, _code),
        ))),
      const SizedBox(height: 10),
      _field('Term *', _term, enabled, focus: _termFocus, maxLength: 500),
      _field('Definition *', _definition, enabled, maxLength: 2000),
      _field('Pronunciation', _pronunciation, enabled),
      _field('Example', _example, enabled, lines: 2),
      _field('Emoji (optional)', _emoji, enabled),
      VocabularyAssetDropZone(audio: false, enabled: enabled, selectedName: _draft.image?.name,
        onFile: (file) => _draft.setMedia(file,isAudio:false), onRemove: () => _draft.removeMedia(false)),
      const SizedBox(height: 12),
      VocabularyAssetDropZone(audio: true, enabled: enabled, selectedName: _draft.audio?.name,
        onFile: (file) => _draft.setMedia(file,isAudio:true), onRemove: () => _draft.removeMedia(true)),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: _draft.allowMissing,
        title: const Text('Explicitly allow missing media'),
        onChanged: enabled ? (v) { _draft.allowMissing = v == true; _draft.schedule(); } : null),
    ]);
  }
  Widget _review(bool enabled) {
    final d = _draft;
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VocabularyLivePreview(draft: d),
      const SizedBox(height: 12),
      Text('Live validation', style: Theme.of(context).textTheme.titleMedium),
      if (d.checking || d.reading || d.publishing) const LinearProgressIndicator(),
      if (d.checking) const Text('Checking current draft…'),
      if (d.themeId == null) const Text('Select a language and theme.'),
      if (d.slug == null && d.term.trim().isNotEmpty && d.definition.trim().isNotEmpty)
        Text('Cannot generate a valid slug for this entry.', style: TextStyle(color: colors.error)),
      if (d.error != null) Text(d.error!, style: TextStyle(color: colors.error)),
      if (d.duplicate) Text('Duplicate record in selected theme.', style: TextStyle(color: colors.error))
      else if (d.sameTerm) const Text('Existing word in selected theme — verify the different meaning.')
      else if (d.validated && d.term.trim().isNotEmpty) const Text('No matching word in this theme.'),
      if (d.slugConflict) Text('Slug belongs to different vocabulary.', style: TextStyle(color: colors.error)),
      if (d.fileConflict) Text('Destination exists with different content. Publishing blocked.',
        style: TextStyle(color: colors.error)),
      for (final path in d.sourceConflicts) Text('Source filename already exists: $path'),
      for (final path in d.existingPaths.where((p) => p == d.imagePath || p == d.audioPath))
        Text('Existing destination: $path${d.fileConflict ? "" : " — reuse available"}'),
      if (!d.allowMissing && (d.image == null || !d.hasAudio))
        const Text('Image and pronunciation are required unless missing media is explicitly allowed.'),
      OutlinedButton(onPressed: enabled && d.themeId != null ? d.schedule : null,
        child: const Text('Revalidate')),
      FilledButton.icon(onPressed: enabled && d.canPublish ? _publish : null,
        icon: const Icon(Icons.cloud_upload), label: Text(d.publishing ? 'Publishing…' : 'Publish & Next')),
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _draft, builder: (context, _) {
      final enabled = !_draft.publishing && !_draft.reading && !_confirming;
      return PopScope(canPop: !_draft.publishing && !_draft.reading && !_confirming, child: Scaffold(
        appBar: AppBar(title: const Text('Fast Upload'), actions: [
          TextButton(onPressed: enabled ? () => Navigator.pop(context) : null,
            child: const Text('Bulk Import')),
        ]),
        body: _loading ? const Center(child: CircularProgressIndicator())
          : _loadError != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!), TextButton(onPressed: _loadScopes, child: const Text('Retry')),
          ]))
          : LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _input(enabled))),
                const VerticalDivider(width: 1),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _review(enabled))),
              ]);
            }
            return SingleChildScrollView(padding: const EdgeInsets.all(16),
              child: Column(children: [_input(enabled), const SizedBox(height: 16), _review(enabled)]));
          }),
      ));
    });
  }
}
