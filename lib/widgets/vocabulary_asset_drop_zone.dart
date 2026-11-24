import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/vocabulary_import_batch.dart';

class VocabularyAssetDropZone extends StatefulWidget {
  final bool audio, enabled;
  final String? selectedName;
  final Future<void> Function(VocabularyLocalAsset) onFile;
  final VoidCallback onRemove;
  const VocabularyAssetDropZone({super.key, required this.audio, required this.enabled,
    required this.selectedName, required this.onFile, required this.onRemove});
  @override
  State<VocabularyAssetDropZone> createState() => _VocabularyAssetDropZoneState();
}

class _VocabularyAssetDropZoneState extends State<VocabularyAssetDropZone> {
  bool _hover = false, _picking = false;
  bool get _enabled => widget.enabled && !_picking;
  bool get _canDrop => kIsWeb || const [
    TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  Future<void> _browse() async {
    if (!_enabled) return;
    setState(() => _picking = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: widget.audio ? const ['mp3'] : const ['png','jpg','jpeg','webp']);
      if (file == null || !mounted || !widget.enabled) return;
      await widget.onFile(VocabularyLocalAsset(file.name, () async {
        final length = await file.length();
        if (length == null) throw const FormatException('File size unavailable.');
        return length;
      }, file.readAsBytes));
    } catch (e) { _message(e.toString()); }
    finally { if (mounted) setState(() => _picking = false); }
  }
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final box = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hover ? color.primary : color.outline),
        color: _hover ? color.primaryContainer : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(widget.audio ? Icons.audiotrack : Icons.image),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.selectedName ?? (widget.audio ? 'MP3 audio' : 'Image'))),
          if (widget.selectedName != null) IconButton(onPressed: _enabled ? widget.onRemove : null,
            icon: const Icon(Icons.close), tooltip: 'Remove file'),
        ]),
        Text(widget.audio ? 'MP3 · up to 10 MB' : 'PNG / JPG / JPEG / WebP · up to 5 MB'),
        OutlinedButton(onPressed: _enabled ? _browse : null,
          child: Text(_canDrop ? 'Drop one file here or browse' : 'Browse files')),
      ]),
    );
    if (!_canDrop) return box;
    return DropTarget(
      onDragEntered: (_) { if (_enabled) setState(() => _hover = true); },
      onDragExited: (_) { if (mounted) setState(() => _hover = false); },
      onDragDone: (details) async {
        if (mounted) setState(() => _hover = false);
        if (!_enabled) return;
        if (details.files.length != 1) { _message('Drop exactly one file in this zone.'); return; }
        final file = details.files.single;
        try { await widget.onFile(VocabularyLocalAsset(file.name, file.length, file.readAsBytes)); }
        catch (e) { _message(e.toString()); }
      },
      child: box,
    );
  }
}
