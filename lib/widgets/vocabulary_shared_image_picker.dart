import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/vocabulary_asset_service.dart';

class VocabularySharedImagePicker extends StatefulWidget {
  final SupabaseClient client;
  final String initialSearch;
  const VocabularySharedImagePicker({super.key, required this.client, this.initialSearch = ''});
  @override
  State<VocabularySharedImagePicker> createState() => _VocabularySharedImagePickerState();
}

class _VocabularySharedImagePickerState extends State<VocabularySharedImagePicker> {
  late final TextEditingController _search;
  late final VocabularyAssetService _assets;
  List<String> _paths = [];
  String? _selected, _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialSearch);
    _assets = VocabularyAssetService(widget.client);
    _load();
  }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      final paths = await _assets.listSharedImages();
      if (mounted) setState(() => _paths = paths);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  String _url(String path) => widget.client.storage.from(VocabularyAssetService.bucket).getPublicUrl(path);
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final words = _search.text.toLowerCase().split(RegExp(r'[\s_]+')).where((w) => w.isNotEmpty);
    final paths = _paths.where((path) => words.every((w) => path.split('/').last.toLowerCase().contains(w))).toList();
    final selected = _selected;
    return AlertDialog(
      title: const Text('Reuse Existing Image'),
      content: SizedBox(width: 520, height: 420, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Shared library — all languages'),
          TextField(controller: _search, onChanged: (_) => setState(() => _selected = null),
            decoration: InputDecoration(labelText: 'Search filenames', prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.clear), tooltip: 'Show all images',
                onPressed: () => setState(() { _search.clear(); _selected = null; })))),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator()
          else if (_error != null) Expanded(child: Center(child: Text(_error!)))
          else ...[
            Expanded(child: paths.isEmpty
              ? const Center(child: Text('No matching images. Clear the search or upload a new image.'))
              : ListView.builder(itemCount: paths.length, itemBuilder: (context, i) {
                final path = paths[i];
                return ListTile(selected: path == selected,
                  leading: SizedBox(width: 48, height: 48,
                    child: Image.network(_url(path), fit: BoxFit.contain, cacheWidth: 96,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
                  title: Text(path.split('/').last),
                  trailing: path == selected ? const Icon(Icons.check_circle) : null,
                  onTap: () => setState(() => _selected = path));
              })),
            if (selected != null) ...[
              const Divider(),
              SizedBox(height: 100, child: Image.network(_url(selected), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(child: Text('Image preview unavailable')))),
              Text(selected, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ],
      )),
      actions: [
        TextButton(onPressed: _loading ? null : _load, child: const Text('Refresh')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: !_loading && _error == null && selected != null
          ? () => Navigator.pop(context, selected) : null, child: const Text('Use Image')),
      ]);
  }
}
