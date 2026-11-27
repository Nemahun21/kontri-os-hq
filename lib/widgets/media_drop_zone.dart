// Port of vocabulary_asset_drop_zone.dart and VocabularyLocalAsset from
// feature/content-intake-pipeline @ 76245730ab8d606046bd133aa822f44e0f8d0bcb.
// Keep file reads lazy; callers retain their existing storage validators.
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MediaLocalAsset {
  final String name;
  final Future<int> Function() length;
  final Future<Uint8List> Function() read;
  const MediaLocalAsset(this.name, this.length, this.read);

  Future<Uint8List> readChecked(int maxBytes) async {
    final size = await length();
    if (size < 12 || size > maxBytes) {
      throw FormatException('Invalid media size: $name');
    }
    final bytes = await read();
    if (bytes.length < 12 || bytes.length > maxBytes) {
      throw FormatException('Invalid media size: $name');
    }
    return bytes;
  }
}

class MediaDropZone extends StatefulWidget {
  final String label, help;
  final List<String> extensions;
  final bool enabled, enableDrop;
  final int maxFiles;
  final Future<void> Function(List<MediaLocalAsset>) onFiles;
  // Injection for widget tests; ordinary use always opens the native picker.
  final Future<List<MediaLocalAsset>> Function()? browseOverride;
  const MediaDropZone({super.key, required this.label, required this.help,
    required this.extensions, required this.enabled, required this.onFiles,
    this.maxFiles = 1, this.enableDrop = true, this.browseOverride});
  @override
  State<MediaDropZone> createState() => _MediaDropZoneState();
}

class _MediaDropZoneState extends State<MediaDropZone> {
  bool _hover = false, _picking = false;
  bool get _enabled => widget.enabled && !_picking;
  bool get _canDrop => widget.enableDrop &&
      !const bool.fromEnvironment('HQ_MEDIA_BROWSE_ONLY') &&
      (kIsWeb || const [TargetPlatform.windows, TargetPlatform.linux,
        TargetPlatform.macOS].contains(defaultTargetPlatform));

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)));
  }

  Future<void> _receive(Future<List<MediaLocalAsset>> Function() load) async {
    if (!_enabled) return;
    setState(() => _picking = true);
    try {
      final files = await load();
      if (!mounted || !widget.enabled || files.isEmpty) return;
      if (files.length > widget.maxFiles) {
        _message(widget.maxFiles == 1 ? 'Select exactly one file.' :
          'Select at most ${widget.maxFiles} files at a time.');
        return;
      }
      await widget.onFiles(files);
    } catch (e) { _message(e.toString()); }
    finally { if (mounted) setState(() => _picking = false); }
  }

  Future<void> _browse() => _receive(() async {
    if (widget.browseOverride != null) return widget.browseOverride!();
    final files = await FilePicker.pickFiles(type: FileType.custom,
      allowedExtensions: widget.extensions);
    return [for (final file in files) MediaLocalAsset(file.name, () async {
      final length = await file.length();
      if (length == null) throw const FormatException('File size unavailable.');
      return length;
    }, file.readAsBytes)];
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final box = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hover && _enabled ? color.primary : color.outline),
        color: _hover && _enabled ? color.primaryContainer : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min, children: [
        Row(children: [const Icon(Icons.cloud_upload_outlined),
          const SizedBox(width: 8), Expanded(child: Text(widget.label))]),
        Text(widget.help),
        OutlinedButton(onPressed: _enabled ? _browse : null,
          child: Text(_canDrop ? 'Drop files here or browse' : 'Browse files')),
      ]),
    );
    if (!_canDrop) return box;
    return DropTarget(
      onDragEntered: (_) { if (_enabled) setState(() => _hover = true); },
      onDragExited: (_) { if (mounted) setState(() => _hover = false); },
      onDragDone: (details) async {
        if (!mounted) return;
        setState(() => _hover = false);
        await _receive(() async => [for (final file in details.files)
          MediaLocalAsset(file.name, file.length, file.readAsBytes)]);
      },
      child: box,
    );
  }
}
