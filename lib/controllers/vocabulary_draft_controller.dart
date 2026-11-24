import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vocabulary_import_batch.dart';
import '../services/lesson_vocab_service.dart';
import '../services/vocabulary_asset_service.dart';
import '../services/vocabulary_import_service.dart';

class DraftMedia {
  final String name;
  final Uint8List bytes;
  const DraftMedia(this.name, this.bytes);
  String get extension => name.split('.').last.toLowerCase();
  VocabularyLocalAsset named(String name) =>
      VocabularyLocalAsset(name, () async => bytes.length, () async => bytes);

  static Future<DraftMedia> load(VocabularyLocalAsset source, {required bool audio}) async {
    final extension = source.name.split('.').last.toLowerCase();
    final extensions = audio ? const ['mp3'] : const ['png', 'jpg', 'jpeg', 'webp'];
    final max = audio ? VocabularyAssetService.maxAudioBytes : VocabularyAssetService.maxImageBytes;
    if (!source.name.contains('.') || !extensions.contains(extension)) {
      throw const FormatException('Unsupported file format.');
    }
    final size = await source.length();
    if (size <= 0 || size > max) throw const FormatException('Invalid media size.');
    final bytes = await source.read();
    if (bytes.length != size || !VocabularyAssetService.validSignature('asset.$extension', bytes)) {
      throw const FormatException('Invalid or changed media file.');
    }
    return DraftMedia(source.name, bytes);
  }
}

class VocabularyDraftController extends ChangeNotifier {
  final SupabaseClient client;
  final LessonVocabularyService vocabulary;
  VocabularyDraftController(this.client, this.vocabulary);
  String? themeId, languageCode;
  String term = '', definition = '', pronunciation = '', example = '', emoji = '';
  DraftMedia? image, audio;
  bool checking = false, reading = false, publishing = false, allowMissing = false;
  bool sameTerm = false, duplicate = false, slugConflict = false, fileConflict = false;
  bool validated = false;
  Set<String> existingPaths = {};
  String? error;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;

  String? get slug {
    if (languageCode == null || term.trim().isEmpty || definition.trim().isEmpty) return null;
    try {
      final value = VocabularyImportService.suggestedSlug(languageCode!, term, definition);
      return value.length <= 180 && VocabularyImportService.validSlug(value) ? value : null;
    } on FormatException { return null; }
  }
  String? get imagePath => image == null || slug == null ? null : 'images/$slug.${image!.extension}';
  String? get audioPath => slug == null ? null : 'audio/$languageCode/$slug.mp3';
  bool get hasAudio => audio != null || existingPaths.contains(audioPath);
  bool get canPublish => !publishing && !reading && !checking && validated &&
      !duplicate && !slugConflict && !fileConflict && error == null && slug != null &&
      (allowMissing || (image != null && hasAudio));

  String? _rawPath(DraftMedia? file, bool isAudio) {
    if (file == null || file.name.contains('/') || file.name.contains('\\')) return null;
    return isAudio ? 'audio/$languageCode/${file.name}' : 'images/${file.name}';
  }
  Set<String> get sourceConflicts => {
    for (final path in [_rawPath(image, false), _rawPath(audio, true)])
      if (path != null && existingPaths.contains(path)) path,
  };
  void _notify() { if (!_disposed) notifyListeners(); }
  void selectTheme(String? id, String? code) {
    themeId = id; languageCode = code; schedule();
  }
  void schedule() {
    _timer?.cancel();
    final revision = ++_revision;
    validated = false; sameTerm = false; duplicate = false; slugConflict = false;
    fileConflict = false; error = null; existingPaths = {};
    checking = themeId != null && (term.trim().isNotEmpty || image != null || audio != null);
    _notify();
    if (checking) {
      _timer = Timer(const Duration(milliseconds: 500), () async { await _validate(revision); });
    }
  }
  Future<void> setMedia(VocabularyLocalAsset source, {required bool isAudio}) async {
    if (reading || publishing) return;
    reading = true; _notify();
    try {
      final media = await DraftMedia.load(source, audio: isAudio);
      if (_disposed) return;
      if (isAudio) { audio = media; } else { image = media; }
      schedule();
    } catch (e) {
      if (!_disposed) {
        if (isAudio) { audio = null; } else { image = null; }
        schedule();
        _timer?.cancel(); ++_revision; checking = false; validated = false;
        error = e.toString();
      }
    } finally { reading = false; _notify(); }
  }
  void removeMedia(bool isAudio) {
    if (publishing || reading) return;
    if (isAudio) { audio = null; } else { image = null; }
    schedule();
  }
  Future<bool> _validate(int revision) async {
    if (_disposed || revision != _revision || themeId == null) return false;
    final i = image, a = audio, ip = imagePath, ap = audioPath;
    final paths = <String>{
      for (final path in [ip, ap, _rawPath(i, false), _rawPath(a, true)])
        if (path != null) path,
    }.toList();
    try {
      final result = await vocabulary.checkFastDraft(themeId: themeId!, term: term,
          definition: definition, slug: slug, paths: paths);
      if (_disposed || revision != _revision) return false;
      final found = Set<String>.from(result['existing_paths'] as List);
      bool conflict = false;
      for (final entry in [(ip, i), (ap, a)]) {
        final path = entry.$1, media = entry.$2;
        if (path != null && media != null && found.contains(path)) {
          final remote = await client.storage.from(VocabularyAssetService.bucket).download(path);
          if (_disposed || revision != _revision) return false;
          if (!listEquals(remote, media.bytes)) conflict = true;
        }
      }
      if (_disposed || revision != _revision) return false;
      existingPaths = found; sameTerm = result['same_term'] == true;
      duplicate = result['duplicate'] == true; slugConflict = result['slug_conflict'] == true;
      fileConflict = conflict; validated = true; error = null;
      return !duplicate && !slugConflict && !fileConflict;
    } catch (e) {
      if (!_disposed && revision == _revision) {
        validated = false; error = 'Validation unavailable: $e';
      }
      return false;
    } finally {
      if (!_disposed && revision == _revision) { checking = false; _notify(); }
    }
  }
  Future<void> publish() async {
    if (!canPublish) return;
    publishing = true; _timer?.cancel(); checking = true; validated = false; _notify();
    try {
      if (!await _validate(++_revision)) throw StateError(error ?? 'Draft has a conflict.');
      if (_disposed) return;
      if (!allowMissing && (image == null || !hasAudio)) throw StateError('Required media is missing.');
      final target = slug!, ip = imagePath, ap = audioPath!;
      final assetService = VocabularyAssetService(client);
      assetService.setFiles([
        if (image != null) image!.named(ip!.split('/').last),
        if (audio != null) audio!.named(ap.split('/').last),
      ]);
      final importer = VocabularyImportService(client, assetService);
      final batch = await importer.prepare('Fast Upload', [{
        'term': term, 'definition': definition, 'pronunciation': pronunciation,
        'example': example, 'emoji': emoji, 'file_slug': target,
        if (ip != null) 'image_url': ip,
        if (audio != null || existingPaths.contains(ap)) 'audio_url': ap,
      }], contentType: 'language', initialThemeId: themeId);
      final row = batch.rows.single;
      if (row.existingId != null || row.state == ImportState.existing ||
          row.state == ImportState.conflict || (!allowMissing && row.state == ImportState.missing)) {
        throw StateError('Cannot create draft: ${row.issues.join('; ')}');
      }
      row.data['create_only'] = true;
      await importer.commit(batch, allowMissing: allowMissing, save: vocabulary.commitImportRows,
          progress: () {}, cancelled: () => _disposed);
      if (row.state != ImportState.saved) {
        throw StateError(row.error ?? 'Not saved. Revalidate before retrying.');
      }
      term = ''; definition = ''; pronunciation = ''; example = ''; emoji = '';
      image = null; audio = null; allowMissing = false; schedule();
    } catch (e) { error = e.toString(); validated = false; rethrow; }
    finally { publishing = false; _notify(); }
  }
  @override
  void dispose() { _disposed = true; _timer?.cancel(); ++_revision; super.dispose(); }
}
