import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/vocabulary_draft_controller.dart';
import '../services/vocabulary_asset_service.dart';

class VocabularyLivePreview extends StatefulWidget {
  final VocabularyDraftController draft;
  const VocabularyLivePreview({super.key, required this.draft});
  @override
  State<VocabularyLivePreview> createState() => _VocabularyLivePreviewState();
}
class _VocabularyLivePreviewState extends State<VocabularyLivePreview> {
  final _player = AudioPlayer();
  @override
  void initState() { super.initState(); widget.draft.addListener(_stopOnChange); }
  void _stopOnChange() { _player.stop(); }
  @override
  void dispose() {
    widget.draft.removeListener(_stopOnChange); _player.dispose(); super.dispose();
  }
  Future<void> _play() async {
    final d = widget.draft;
    try {
      await _player.stop();
      if (d.audio != null) {
        await _player.play(BytesSource(d.audio!.bytes, mimeType: 'audio/mpeg'));
      } else if (d.hasAudio && d.audioPath != null) {
        final url = Supabase.instance.client.storage.from(VocabularyAssetService.bucket).getPublicUrl(d.audioPath!);
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child:
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Live flashcard preview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: d.image == null
          ? const Center(child: Icon(Icons.image_outlined, size: 64))
          : Image.memory(d.image!.bytes, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Text('Image cannot be decoded')))),
        Text(d.term.isEmpty ? 'Term' : d.term, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
        Text(d.definition.isEmpty ? 'Definition' : d.definition, textAlign: TextAlign.center),
        if (d.pronunciation.isNotEmpty) Text(d.pronunciation, textAlign: TextAlign.center),
        if (d.example.isNotEmpty) Text(d.example, textAlign: TextAlign.center),
        if (d.emoji.isNotEmpty) Text(d.emoji, textAlign: TextAlign.center),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: d.hasAudio ? _play : null, icon: const Icon(Icons.play_arrow),
            tooltip: 'Play pronunciation'),
          IconButton(onPressed: () => _player.stop(), icon: const Icon(Icons.stop), tooltip: 'Stop audio'),
        ]),
        const Divider(), const Text('Generated file_slug'),
        SelectableText(d.slug ?? 'Enter term and definition'),
        if (d.imagePath != null) SelectableText(d.imagePath!),
        if (d.audioPath != null) SelectableText(d.audioPath!),
      ])));
  }
}
