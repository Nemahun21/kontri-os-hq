import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../services/intake_folder_stub.dart'
  if (dart.library.io) '../../services/intake_folder_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/vocabulary_import_batch.dart';
import '../../services/vocabulary_asset_service.dart';
import '../../services/vocabulary_import_service.dart';
import '../../services/lesson_vocab_service.dart';
import '../../services/xlsx_reader.dart';
import 'vocabulary_fast_upload_view.dart';

class VocabularyBulkImportScreen extends StatefulWidget {
  final String contentType;
  final String? initialThemeId;
  final String? initialCategory;
  final String initialDifficulty;
  const VocabularyBulkImportScreen({super.key, required this.contentType,
    this.initialThemeId, this.initialCategory, this.initialDifficulty = 'easy'});

  @override
  State<VocabularyBulkImportScreen> createState() => _VocabularyBulkImportScreenState();
}

class _VocabularyBulkImportScreenState extends State<VocabularyBulkImportScreen> {
  late final VocabularyAssetService _assets;
  late final VocabularyImportService _importer;
  final _vocabulary = LessonVocabularyService();
  final _player = AudioPlayer();
  List<Map<String, String>>? _source;
  String _name = '';
  List<VocabularyLocalAsset> _files = [];
  VocabularyImportBatch? _batch;
  bool _busy = false;
  bool _committing = false;
  bool _stop = false;
  bool get _folderSupported => !kIsWeb &&
      [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS].contains(defaultTargetPlatform);
  bool get _test1 => Uri.parse(Supabase.instance.client.supabaseUrl).host == 'eeeusvsefoxbgshouqjb.supabase.co';
  String _status = '';
  ImportState? _filter;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _assets = VocabularyAssetService(client);
    _importer = VocabularyImportService(client, _assets);
  }

  @override
  void dispose() {
    _stop = true;
    _player.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  // file_picker v13 returns null when file size cannot be determined.
  // Fail closed rather than bypassing the manifest and media size limits.
  Future<int> _requiredFileLength(PlatformFile file) async {
    final size = await file.length();
    if (size == null) {
      throw FormatException('Could not determine file size: ${file.name}. Select the file again.');
    }
    return size;
  }

  Future<void> _pickManifest() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
          allowedExtensions: const ['csv','txt','xlsx']);
      if (file == null || !mounted) return;
      if (await _requiredFileLength(file) > 20 * 1024 * 1024) {
        throw const FormatException('Manifest exceeds 20 MB. Split the batch.');
      }
      var bytes = await file.readAsBytes();
      final extension = file.name.toLowerCase().split('.').last;
      if (extension == 'xlsx') {
        final sheets = XlsxReader.read(bytes);
        if (sheets.isEmpty) throw const FormatException('Workbook has no visible data sheets.');
        if (sheets.length > 1) {
          if (!mounted) return;
          final choice = await showDialog<int>(context: context, builder: (context) =>
            SimpleDialog(title: const Text('Choose worksheet'), children: [
              for (var i = 0; i < sheets.length; i++)
                SimpleDialogOption(onPressed: () => Navigator.pop(context, i),
                  child: Text(sheets[i].name)),
              SimpleDialogOption(onPressed: () => Navigator.pop(context, -1),
                  child: const Text('All sheets with identical headers')),
            ]));
          if (choice == null) return;
          bytes = XlsxReader.toCsv(choice == -1 ? sheets : [sheets[choice]]);
        } else {
          bytes = XlsxReader.toCsv(sheets);
        }
      }
      final rows = VocabularyImportService.parse(bytes, txt: extension == 'txt');
      if (rows.isEmpty) throw const FormatException('No content rows.');
      if (widget.contentType == 'language' && rows.any((r) => (r['file_slug'] ?? '').trim().isEmpty)) throw const FormatException('Every row needs file_slug.');
      if (!mounted) return;
      setState(() {
        _source = rows;
        _name = file.name;
        _batch = null;
        _status = '${rows.length} rows loaded. Select media, then validate.';
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _imageExtensions = {'png','jpg','jpeg','webp'};
  static const _audioExtensions = {'mp3'};

  Future<void> _pickFolder(bool audio) async {
    setState(() => _busy = true);
    try {
      final extensions = audio ? _audioExtensions : _imageExtensions;
      final files = await pickIntakeFolder(extensions);
      if (files == null || !mounted) return;
      setState(() {
        _files = [..._files.where((f) => !extensions.contains(f.name.split('.').last.toLowerCase())), ...files];
        _batch = null;
        _status = '${files.length} media files selected from folder.';
      });
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _pickMedia() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom,
        allowedExtensions: const ['png','jpg','jpeg','webp','mp3']);
      if (files.isEmpty || !mounted) return;
      setState(() {
        _files = [..._files, for (final f in files)
          VocabularyLocalAsset(f.name, () => _requiredFileLength(f), f.readAsBytes)];
        _batch = null;
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    if (_source == null) return;
    setState(() {
      _busy = true; _batch = null; _status = 'Reading database and Storage…';
      _filter = null;
    });
    try {
      _assets.setFiles(_files);
      final batch = await _importer.prepare(_name, _source!,
        contentType: widget.contentType, initialThemeId: widget.initialThemeId,
        initialCategory: widget.initialCategory, initialDifficulty: widget.initialDifficulty,
        progress: (done, total) {
          if (mounted && (done % 10 == 0 || done == total)) {
            setState(() => _status = 'Validating $done / $total');
          }
        });
      if (mounted) setState(() {
        _batch = batch;
        _status = 'Review results before publishing.';
      });
    } catch (e) {
      _error(e);
      if (mounted) setState(() => _status = 'Validation failed. Nothing was imported.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _hasImage(VocabularyImportRow r) => r.existingImage != null || r.image?.available == true;
  bool _hasAudio(VocabularyImportRow r) => r.existingAudio != null || r.audio?.available == true;
  int get _eligible => _batch?.count(ImportState.ready) ?? 0;
  bool get _canPublish => _test1 && _eligible > 0 &&
      (_batch?.rows.every((r) => (r.state == ImportState.ready || r.state == ImportState.existing) && _hasImage(r) && _hasAudio(r)) ?? false);

  Future<void> _saveDrafts() async {
    final batch = _batch;
    if (!_test1 || batch == null || widget.contentType != 'language' || _busy) return;
    final selected = batch.rows.where((r) => r.state == ImportState.ready || r.state == ImportState.missing).toList();
    if (selected.isEmpty || batch.count(ImportState.conflict) > 0) return;
    setState(() { _busy = true; _committing = true; _stop = false; _status = 'Saving drafts…'; });
    final client = Supabase.instance.client;
    try {
      for (final row in selected) {
        if (_stop || !mounted) break;
        try {
          final data = Map<String,dynamic>.from(row.data);
          final theme = data['theme_id'] as String;
          final difficulty = _source![row.line - 2]['difficulty']?.trim().toLowerCase();
          data['difficulty'] = ['easy','medium','hard'].contains(difficulty) ? difficulty : widget.initialDifficulty;
          if (data['position'] == null) {
            final live = await client.from('lesson_vocabulary').select('position').eq('theme_id',theme).order('position',ascending:false).limit(1);
            final drafts = await client.from('lesson_vocabulary_revisions').select('position').eq('theme_id',theme).order('position',ascending:false).limit(1);
            var max = 0;
            for (final entry in [...live,...drafts]) {
              final p = (entry['position'] as num?)?.toInt() ?? 0;
              if (p > max) max = p;
            }
            data['position'] = max + 1;
          }
          if (row.image?.available == true) data['image_url'] = await _assets.ensureUploaded(row.image!);
          if (row.audio?.available == true) data['audio_url'] = await _assets.ensureUploaded(row.audio!);
          await client.rpc('v2_save_vocab_draft',params:{'p_row':data});
          row.state = ImportState.saved;
        } catch (e) { row.state = ImportState.failed; row.error = e.toString(); }
        if (mounted) setState(() => _status = 'Drafts saved: ${batch.count(ImportState.saved)} · Failed: ${batch.count(ImportState.failed)}');
      }
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() { _busy = false; _committing = false; }); }
  }

  Future<void> _publish() async {
    final batch = _batch;
    if (batch == null || !_canPublish) return;
    // The existing theme review workflow owns persisted revisions. Never
    // create a second live identity for a previously saved draft.
    if (widget.contentType == 'language') {
      setState(() => _busy = true);
      try {
        final client = Supabase.instance.client;
        for (final row in batch.rows.where((r) => r.state == ImportState.ready)) {
          final revisions = await client.from('lesson_vocabulary_revisions')
              .select('id,term,definition,file_slug,status')
              .eq('theme_id', row.data['theme_id'] as String)
              .inFilter('status', ['draft','pending_approval']);
          final hasDraft = revisions.any((d) =>
              d['file_slug'] == row.data['file_slug'] ||
              (VocabularyImportService.identity(d) == VocabularyImportService.identity(row.data)));
          if (hasDraft) {
            throw StateError('This entry already has a saved draft. Complete it using Save as Draft, then publish through the existing theme review workflow.');
          }
        }
      } catch (e) { _error(e); return; }
      finally { if (mounted) setState(() => _busy = false); }
      if (!mounted) return;
    }
    final accepted = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Approve batch'),
        content: Text('Publish $_eligible eligible records? Existing text is not overwritten. '
          'Both image and audio are required. This publishes to the connected Test1 learner database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publish')),
        ]));
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true; _committing = true; _stop = false;
      _status = 'Publishing…';
    });
    try {
      await _importer.commit(batch, allowMissing: false,
        save: _vocabulary.commitImportRows,
        cancelled: () => _stop || !mounted,
        progress: () {
          if (mounted) setState(() => _status =
            'Saved ${batch.count(ImportState.saved)} · Failed ${batch.count(ImportState.failed)}');
        });
      if (mounted) setState(() => _status = _stop
        ? 'Stopped safely. Validate again to resume.'
        : 'Finished: ${batch.count(ImportState.saved)} saved, ${batch.count(ImportState.failed)} failed. '
          'Validate again before retrying.');
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() { _busy = false; _committing = false; });
    }
  }

  Future<void> _play(VocabularyImportRow row) async {
    try {
      await _player.stop();
      final local = row.audio?.local;
      if (local != null) {
        if (await local.length() > VocabularyAssetService.maxAudioBytes) {
          throw const FormatException('Audio exceeds preview limit.');
        }
        final bytes = await local.read();
        if (bytes.length > VocabularyAssetService.maxAudioBytes ||
            !VocabularyAssetService.validSignature('sample.mp3', bytes)) {
          throw const FormatException('Invalid MP3.');
        }
        await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      } else {
        final url = row.existingAudio ?? (row.audio?.remote == true
          ? Supabase.instance.client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.audio!.path)
          : null);
        if (url != null) await _player.play(UrlSource(url));
      }
    } catch (e) { _error(e); }
  }

  Future<void> _preview(VocabularyImportRow row) async {
    Uint8List? bytes;
    try {
      final local = row.image?.local;
      if (local != null) {
        if (await local.length() > VocabularyAssetService.maxImageBytes) {
          throw const FormatException('Image exceeds preview limit.');
        }
        bytes = await local.read();
        if (bytes.length > VocabularyAssetService.maxImageBytes ||
            !VocabularyAssetService.validSignature(row.image!.path, bytes)) {
          throw const FormatException('Invalid image.');
        }
      }
    } catch (e) { _error(e); return; }
    if (!mounted) return;
    final url = row.existingImage ?? (row.image?.remote == true
      ? Supabase.instance.client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.image!.path)
      : null);
    await showDialog<void>(context: context, builder: (context) =>
      AlertDialog(title: Text(row.data['term'].toString()),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            if (bytes != null) Image.memory(bytes!, height: 180, errorBuilder: (_, __, ___) => const Text('Invalid image'))
            else if (url != null) Image.network(url, height: 180, errorBuilder: (_, __, ___) => const Text('Image unavailable'))
            else const Text('No image'),
            Text(row.data['definition'].toString()),
            if (row.data['file_slug'] != null) SelectableText(row.data['file_slug'].toString()),
            Text('Image: ${row.image?.path ?? row.existingImage ?? "not linked"}'),
            Text('Audio: ${row.audio?.path ?? row.existingAudio ?? "not linked"}'),
            if (row.audio?.available == true || row.existingAudio != null)
              TextButton.icon(onPressed: () => _play(row), icon: const Icon(Icons.volume_up), label: const Text('Play audio')),
            for (final issue in row.issues) Text(issue),
            if (row.error != null) Text(row.error!),
          ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
    await _player.stop();
  }

  Future<void> _copyReport() async {
    final batch = _batch;
    if (batch == null) return;
    final report = StringBuffer('Vocabulary batch: ${batch.name}\n');
    for (final row in batch.rows) {
      report.writeln('Record ${row.line}: ${row.data['term']} — ${row.state.name} '
        '${row.issues.join("; ")} ${row.error ?? ""}');
    }
    await Clipboard.setData(ClipboardData(text: report.toString()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch report copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    final rows = batch?.rows.where((r) => _filter == null || r.state == _filter).toList() ?? [];
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: const Text('Bulk Asset Import Studio'), actions: [
        if (widget.contentType == 'language')
          TextButton.icon(
            onPressed: _busy ? null : () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => VocabularyFastUploadView(
                initialThemeId: widget.initialThemeId))),
            icon: const Icon(Icons.bolt), label: const Text('Fast Upload')),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select a manifest, image folder and MP3 folder. Exact file_slug matches only. No asset is overwritten.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _busy ? null : _pickManifest,
                icon: const Icon(Icons.description), label: const Text('CSV / TXT / XLSX')),
              OutlinedButton.icon(onPressed: _busy || !_folderSupported ? null : () => _pickFolder(false),
                icon: const Icon(Icons.folder_open), label: const Text('Image folder')),
              OutlinedButton.icon(onPressed: _busy || !_folderSupported ? null : () => _pickFolder(true),
                icon: const Icon(Icons.folder_open), label: const Text('Audio folder')),
              OutlinedButton.icon(onPressed: _busy ? null : _pickMedia,
                icon: const Icon(Icons.perm_media), label: const Text('Add media files')),
              TextButton(onPressed: _busy ? null : () => setState(() { _files = []; _batch = null; }),
                child: const Text('Clear media')),
              FilledButton(onPressed: _busy || _source == null ? null : _validate,
                child: const Text('Validate / resume')),
              if (_committing) OutlinedButton(onPressed: _stop ? null : () => setState(() => _stop = true),
                child: const Text('Stop after current work')),
              if (batch != null) TextButton(onPressed: _busy ? null : _copyReport, child: const Text('Copy report')),
            ]),
            Text('${_source?.length ?? 0} records · ${_files.length} selected files'),
            Text(_status),
            if (_busy) const LinearProgressIndicator(),
            if (batch != null) ...[
              Wrap(spacing: 6, runSpacing: 4, children: [
                ChoiceChip(label: const Text('All'), selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null)),
                for (final state in ImportState.values)
                  ChoiceChip(label: Text('${state.name}: ${batch.count(state)}'),
                    selected: _filter == state, onSelected: (_) => setState(() => _filter = state)),
              ]),
              Text('Total rows: ${batch.rows.length}'),
              Text('Images matched: ${batch.rows.where(_hasImage).length} / ${batch.rows.where((r) => !_hasImage(r)).length} missing'),
              Text('Audio matched: ${batch.rows.where(_hasAudio).length} / ${batch.rows.where((r) => !_hasAudio(r)).length} missing'),
              if (!_test1) const Text('Intake writes are disabled outside Test1.'),
              if (widget.contentType != 'language') const Text('Persistent drafts are available for language vocabulary only.'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: _busy || !_test1 || widget.contentType != 'language' ||
                    batch.count(ImportState.conflict) > 0 || (_eligible + batch.count(ImportState.missing)) == 0 ? null : _saveDrafts,
                  icon: const Icon(Icons.save_outlined), label: const Text('Save as Draft')),
                FilledButton.icon(onPressed: _busy || !_canPublish ? null : _publish,
                  icon: const Icon(Icons.cloud_upload), label: Text('Publish to Live ($_eligible)')),
              ]),
            ],
          ])),
        Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final row = rows[i];
          return ListTile(
            title: Text('${row.data['term']} — ${row.data['definition']}'),
            subtitle: Text('${row.state.name} · ${row.data['file_slug'] ?? "legacy"}'
              '${row.issues.isEmpty ? "" : "\n" + row.issues.join("; ")}'
              '${row.error == null ? "" : "\n" + row.error!}', maxLines: 4, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.preview), tooltip: 'Preview media',
              onPressed: _busy ? null : () => _preview(row)),
          );
        })),
      ]),
    ));
  }
}
