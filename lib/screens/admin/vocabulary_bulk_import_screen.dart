import 'dart:typed_data';
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
  bool _allowMissing = false;
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

  Future<void> _pickManifest() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom,
          allowedExtensions: const ['csv','txt','xlsx']);
      if (files.isEmpty || !mounted) return;
      final file = files.first;
      if (await file.length() > 20 * 1024 * 1024) {
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
      if (!mounted) return;
      setState(() {
        _source = rows;
        _name = file.name;
        _batch = null;
        _allowMissing = false;
        _status = '${rows.length} rows loaded. Select media, then validate.';
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMedia() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom,
        allowedExtensions: const ['png','jpg','jpeg','webp','mp3'],
        allowMultiple: true);
      if (files.isEmpty || !mounted) return;
      setState(() {
        _files = [..._files, for (final f in files)
          VocabularyLocalAsset(f.name, f.length, f.readAsBytes)];
        _batch = null;
        _allowMissing = false;
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
      _allowMissing = false; _filter = null;
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

  int get _eligible => (_batch?.count(ImportState.ready) ?? 0) +
      (_allowMissing ? (_batch?.count(ImportState.missing) ?? 0) : 0);

  Future<void> _publish() async {
    final batch = _batch;
    if (batch == null || _eligible == 0) return;
    final accepted = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Approve batch'),
        content: Text('Publish $_eligible eligible records? Existing text is not overwritten. '
          'Missing media will stay unlinked only if you explicitly allowed it. '
          'Conflicts are excluded.'),
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
      await _importer.commit(batch, allowMissing: _allowMissing,
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
      appBar: AppBar(title: const Text('Bulk Asset Import Studio')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select a manifest and optional media. Images require explicit paths; '
              'language audio matches the file_slug. No asset is overwritten.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _busy ? null : _pickManifest,
                icon: const Icon(Icons.description), label: const Text('CSV / TXT / XLSX')),
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
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: _allowMissing,
                title: const Text('Explicitly allow entries with missing media'),
                subtitle: const Text('Existing media is preserved. Conflicts are never imported.'),
                onChanged: _busy ? null : (v) => setState(() => _allowMissing = v == true)),
              FilledButton.icon(onPressed: _busy || _eligible == 0 ? null : _publish,
                icon: const Icon(Icons.cloud_upload), label: Text('Review & publish $_eligible')),
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
