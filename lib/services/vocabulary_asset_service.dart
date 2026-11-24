import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vocabulary_import_batch.dart';

class VocabularyAssetService {
  static const bucket = 'vocabulary_assets';
  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxAudioBytes = 10 * 1024 * 1024;
  final SupabaseClient client;
  VocabularyAssetService(this.client);

  final Map<String, List<VocabularyLocalAsset>> _locals = {};
  final Map<String, Set<String>> _remoteFolders = {};
  final Set<String> _confirmed = {};
  final Set<String> _validated = {};

  void setFiles(List<VocabularyLocalAsset> files) {
    _locals.clear();
    _remoteFolders.clear();
    _confirmed.clear();
    _validated.clear();
    for (final file in files) {
      final key = file.name;
      (_locals[key] ??= []).add(file);
    }
  }

  static bool validPath(String path, {required bool audio}) {
    final pattern = audio
        ? r'^audio/[a-z0-9_]+/[a-z0-9]+(?:_[a-z0-9]+)*\.mp3$'
        : r'^images/[a-z0-9]+(?:_[a-z0-9]+)*\.(?:png|jpg|jpeg|webp)$';
    return RegExp(pattern).hasMatch(path);
  }

  String pathFromReference(String reference, {required bool audio}) {
    var path = reference.trim();
    if (path.startsWith('https://')) {
      const marker = 'asset_probe_marker';
      final probe = client.storage.from(bucket).getPublicUrl(marker);
      final prefix = probe.substring(0, probe.length - marker.length);
      if (!path.startsWith(prefix)) {
        throw const FormatException('Only this project vocabulary bucket is accepted.');
      }
      path = path.substring(prefix.length);
    }
    if (!validPath(path, audio: audio)) {
      throw FormatException('Invalid vocabulary asset path: $path');
    }
    return path;
  }

  Future<Set<String>> _folder(String folder) async {
    if (_remoteFolders.containsKey(folder)) return _remoteFolders[folder]!;
    final names = <String>{};
    for (var offset = 0;; offset += 100) {
      final page = await client.storage.from(bucket).list(
        path: folder,
        searchOptions: SearchOptions(limit: 100, offset: offset),
      );
      names.addAll(page.where((item) => item.id != null).map((item) => item.name));
      if (page.length < 100) break;
    }
    return _remoteFolders[folder] = names;
  }

  Future<List<String>> listSharedImages() async {
    _remoteFolders.remove('images');
    final names = await _folder('images');
    return names.map((name) => 'images/$name')
        .where((path) => validPath(path, audio: false)).toList()..sort();
  }

  Future<VocabularyAssetMatch> match(String reference, {required bool audio}) async {
    final path = pathFromReference(reference, audio: audio);
    final slash = path.lastIndexOf('/');
    final folder = path.substring(0, slash);
    final name = path.substring(slash + 1);
    final choices = _locals[name] ?? const <VocabularyLocalAsset>[];
    if (choices.length > 1) {
      throw FormatException('Multiple selected files named $name. Select just one.');
    }
    final local = choices.isEmpty ? null : choices.single;
    if (local != null) {
      final size = await local.length();
      if (size <= 0 || size > (audio ? maxAudioBytes : maxImageBytes)) {
        throw FormatException('Invalid file size for $name.');
      }
    }
    final remote = (await _folder(folder)).contains(name);
    if (local != null && !_validated.contains(path)) {
      final bytes = await local.read();
      if (bytes.length > (audio ? maxAudioBytes : maxImageBytes) ||
          !validSignature(path, bytes)) {
        throw FormatException('Invalid media signature: $name');
      }
      if (remote) {
        final existing = await client.storage.from(bucket).download(path);
        if (!listEquals(existing, bytes)) {
          throw StateError('Different asset already exists: $path');
        }
      }
      _validated.add(path);
    }
    return VocabularyAssetMatch(path, local: local, remote: remote);
  }

  static String mime(String path) {
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static bool validSignature(String path, Uint8List bytes) {
    if (bytes.length < 12) return false;
    if (path.endsWith('.mp3')) {
      return (bytes[0] == 73 && bytes[1] == 68 && bytes[2] == 51) ||
          (bytes[0] == 255 && (bytes[1] & 224) == 224);
    }
    if (path.endsWith('.png')) {
      return listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    }
    if (path.endsWith('.webp')) {
      return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    }
    return bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
  }

  /// Upload without overwrite. A retry may reuse a byte-identical object.
  /// Different content at the same path is always a conflict.
  Future<String> ensureUploaded(VocabularyAssetMatch match) async {
    final path = match.path;
    final store = client.storage.from(bucket);
    if (_confirmed.contains(path)) return store.getPublicUrl(path);
    if (!match.available) throw StateError('Missing asset: $path');
    if (match.local != null) {
      final file = match.local!;
      final max = path.endsWith('.mp3') ? maxAudioBytes : maxImageBytes;
      if (await file.length() > max) throw FormatException('File too large: $path');
      final bytes = await file.read();
      if (bytes.length > max || !validSignature(path, bytes)) {
        throw FormatException('Unexpected or invalid media format: $path');
      }
      if (!match.remote) {
        try {
          await store.uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: mime(path), upsert: false));
        } on StorageException catch (e) {
          // The response may have been lost, or another import may have won.
          // Reuse only after confirming byte equality below.
          if (e.statusCode != '409' && e.statusCode != '400') rethrow;
          final existing = await store.download(path);
          if (!listEquals(existing, bytes)) {
            throw StateError('Different asset already exists: $path');
          }
        }
      } else {
        final existing = await store.download(path);
        if (!listEquals(existing, bytes)) {
          throw StateError('Different asset already exists: $path');
        }
      }
    } else {
      // The server-side import function rechecks existence when saving.
      // Remote-only assets were indexed during validation.
    }
    _confirmed.add(path);
    return store.getPublicUrl(path);
  }
}
