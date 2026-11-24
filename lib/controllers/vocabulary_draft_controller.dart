import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vocabulary_import_batch.dart';
import '../services/lesson_vocab_service.dart';
import '../services/vocabulary_asset_service.dart';
import '../services/vocabulary_import_service.dart';
import '../services/audio_import_service.dart';
import '../models/lesson_vocab.dart';

class DraftMedia {
  final String name;
  final Uint8List bytes;
  const DraftMedia(this.name, this.bytes);
  String get extension => name.split('.').last.toLowerCase();
  VocabularyLocalAsset named(String name) =>
      VocabularyLocalAsset(name, () async => bytes.length, () async => bytes);

  bool get convertedToMp3 => AudioImportService.extensions.contains(extension) && extension != 'mp3';

  static Future<DraftMedia> load(VocabularyLocalAsset source, {required bool audio}) async {
    if (audio) {
      return DraftMedia(source.name, await AudioImportService.prepare(source));
    }
    final extension = source.name.split('.').last.toLowerCase();
    const extensions = ['png', 'jpg', 'jpeg', 'webp'];
    const max = VocabularyAssetService.maxImageBytes;
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
  VocabularyDraftController(this.client, this.vocabulary, {this.original}) {
    final old = original;
    if (old != null) {
      term = old.term; definition = old.definition;
      pronunciation = old.pronunciation ?? ''; example = old.example ?? ''; emoji = old.emoji ?? '';
      allowMissing = true;
    }
  }
  final LessonVocabulary? original;
  bool get isEdit => original != null;
  bool get hasUnsavedChanges => isEdit ? (term != original!.term || definition != original!.definition ||
      pronunciation != (original!.pronunciation ?? '') || example != (original!.example ?? '') ||
      emoji != (original!.emoji ?? '') || imageChanged || audioChanged) :
      (term.isNotEmpty || definition.isNotEmpty || pronunciation.isNotEmpty || example.isNotEmpty ||
        emoji.isNotEmpty || image != null || audio != null || sharedImagePath != null || reusedAudioPath != null);
  bool imageChanged = false, audioChanged = false;
  String? get preservedImage => isEdit && !imageChanged ? original!.imageUrl : null;
  String? get preservedAudio => isEdit && !audioChanged ? original!.audioUrl : null;
  static bool linked(String? value) => value != null && value.trim().isNotEmpty;
  String? get selectedImageName => image?.name ?? sharedImagePath?.split('/').last ??
      (linked(preservedImage) ? 'Existing illustration' : null);
  String? get selectedAudioName => audio?.name ?? reusedAudioPath?.split('/').last ??
      (linked(preservedAudio) ? 'Existing recording' : null);

  String? themeId, languageCode;
  String term = '', definition = '', pronunciation = '', example = '', emoji = '';
  DraftMedia? image, audio;
  String? sharedImagePath, reusedAudioPath;
  String? _imageRevision, _audioRevision, _resolutionSlug;
  String? _imageOriginal, _audioOriginal;
  Set<String> conflictPaths = {};
  Map<String, int> referenceCounts = {};
  bool checking = false, reading = false, publishing = false, allowMissing = false;
  bool convertingAudio = false;
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
      final oldSlug = original?.fileSlug;
      if (oldSlug != null && oldSlug.length <= 180 &&
          VocabularyImportService.validSlug(oldSlug) && oldSlug.startsWith('${languageCode}_')) {
        return oldSlug;
      }
      final value = VocabularyImportService.suggestedSlug(languageCode!, term, definition);
      return value.length <= 180 && VocabularyImportService.validSlug(value) ? value : null;
    } on FormatException { return null; }
  }
  String? get imagePath => resolveImagePath(sharedPath: sharedImagePath,
      slug: slug, localExtension: image?.extension, revision: _imageRevision);
  static String revisionPath(String path, String version) {
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(version)) {
      throw const FormatException('Invalid revision token.');
    }
    final dot = path.lastIndexOf('.');
    return '${path.substring(0,dot)}_v$version${path.substring(dot)}';
  }
  static String _newRevision() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
  }
  static String? resolveImagePath({String? sharedPath, String? slug, String? localExtension, String? revision}) {
    if (sharedPath != null) {
      if (!VocabularyAssetService.validPath(sharedPath, audio: false)) {
        throw const FormatException('Invalid shared image path.');
      }
      return sharedPath;
    }
    if (slug == null || localExtension == null) return null;
    final path = 'images/$slug.$localExtension';
    return revision == null ? path : revisionPath(path, revision);
  }
  bool get hasImage => linked(preservedImage) || image != null ||
      (sharedImagePath != null && existingPaths.contains(sharedImagePath));
  String? get sharedImageUrl => sharedImagePath == null ? preservedImage :
      client.storage.from(VocabularyAssetService.bucket).getPublicUrl(sharedImagePath!);
  String? get audioPath {
    if (slug == null) return null;
    if (isEdit && (!audioChanged || (audio == null && reusedAudioPath == null))) return null;
    if (reusedAudioPath != null) return reusedAudioPath;
    final path = 'audio/$languageCode/$slug.mp3';
    return _audioRevision == null ? path : revisionPath(path, _audioRevision!);
  }
  bool get hasAudio => linked(preservedAudio) || audio != null || existingPaths.contains(audioPath);
  String? get playbackAudioUrl => linked(preservedAudio) ? preservedAudio :
      (audioPath == null || !existingPaths.contains(audioPath) ? null : client.storage.from(VocabularyAssetService.bucket).getPublicUrl(audioPath!));
  bool get canPublish => !publishing && !reading && !checking && validated &&
      !duplicate && !slugConflict && !fileConflict && error == null && slug != null &&
      (sharedImagePath == null || hasImage) && (reusedAudioPath == null || hasAudio) &&
      (allowMissing || (hasImage && hasAudio));

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
    if (_resolutionSlug != slug) {
      reusedAudioPath = null; _imageRevision = null; _audioRevision = null;
      _imageOriginal = null; _audioOriginal = null;
      if (isEdit) {
        if (image != null) _imageRevision = _newRevision();
        if (audio != null) _audioRevision = _newRevision();
      }
      _resolutionSlug = slug;
    }
    _timer?.cancel();
    final revision = ++_revision;
    validated = false; sameTerm = false; duplicate = false; slugConflict = false;
    fileConflict = false; error = null; existingPaths = {}; conflictPaths = {}; referenceCounts = {};
    checking = themeId != null && (term.trim().isNotEmpty || image != null || sharedImagePath != null || audio != null);
    _notify();
    if (checking) {
      _timer = Timer(const Duration(milliseconds: 500), () async { await _validate(revision); });
    }
  }
  void selectSharedImage(String path) {
    if (reading || publishing || _disposed) return;
    if (!VocabularyAssetService.validPath(path, audio: false)) {
      throw const FormatException('Invalid shared image path.');
    }
    imageChanged = true; image = null; sharedImagePath = path; _imageRevision = null; _imageOriginal = null; schedule();
  }

  bool canReplace(String path) =>
      conflictPaths.contains(path) && referenceCounts[path] == 0 && slug != null;

  void reuseStored(String path) {
    if (reading || publishing || checking || !conflictPaths.contains(path)) return;
    if (path == imagePath) {
      selectSharedImage(path);
    } else if (path == audioPath && slug != null &&
        VocabularyImportService.validLanguageAudioPath(path, languageCode!, slug!)) {
      audioChanged = true; audio = null; reusedAudioPath = path; _audioRevision = null; _audioOriginal = null;
      _resolutionSlug = slug; schedule();
    }
  }

  void replaceWithRevision(String path) {
    if (reading || publishing || checking || !canReplace(path)) return;
    if (path == imagePath && image != null) {
      _imageOriginal ??= path; _imageRevision = _newRevision();
    } else if (path == audioPath && audio != null) {
      _audioOriginal ??= path; _audioRevision = _newRevision();
    } else { return; }
    _resolutionSlug = slug;
    schedule();
  }

  Future<void> setMedia(VocabularyLocalAsset source, {required bool isAudio}) async {
    if (reading || publishing) return;
    reading = true;
    convertingAudio = isAudio && source.name.split('.').last.toLowerCase() != 'mp3';
    _notify();
    try {
      final media = await DraftMedia.load(source, audio: isAudio);
      if (_disposed) return;
      if (isAudio) {
        audioChanged = true; audio = media; reusedAudioPath = null; _audioOriginal = null;
        _audioRevision = isEdit ? _newRevision() : null;
      } else {
        imageChanged = true; image = media; sharedImagePath = null; _imageOriginal = null;
        _imageRevision = isEdit ? _newRevision() : null;
      }
      if (isEdit) _resolutionSlug = slug;
      schedule();
    } catch (e) {
      if (!_disposed) {
        // Failed selection must never discard the current approved media.
        schedule();
        _timer?.cancel(); ++_revision; checking = false; validated = false;
        error = e.toString();
      }
    } finally { reading = false; convertingAudio = false; _notify(); }
  }
  void removeMedia(bool isAudio) {
    if (publishing || reading) return;
    if (isAudio) { audioChanged = true; audio = null; reusedAudioPath = null; _audioRevision = null; _audioOriginal = null; }
    else { imageChanged = true; image = null; sharedImagePath = null; _imageRevision = null; _imageOriginal = null; }
    schedule();
  }
  Future<bool> _validate(int revision) async {
    if (_disposed || revision != _revision || themeId == null) return false;
    final i = image, a = audio, ip = imagePath, ap = audioPath;
    final paths = <String>{
      for (final path in [ip, ap, _rawPath(i, false), _rawPath(a, true), _imageOriginal, _audioOriginal])
        if (path != null) path,
    }.toList();
    try {
      final result = await vocabulary.checkFastDraft(themeId: themeId!, term: term,
          definition: definition, slug: slug, paths: paths, editingId: original?.id);
      if (_disposed || revision != _revision) return false;
      final found = Set<String>.from(result['existing_paths'] as List);
      final counts = Map<String, int>.from(result['reference_counts'] as Map);
      final conflicts = <String>{};
      for (final entry in [(ip, i), (ap, a)]) {
        final path = entry.$1, media = entry.$2;
        if (path != null && media != null && found.contains(path)) {
          final remote = await client.storage.from(VocabularyAssetService.bucket).download(path);
          if (_disposed || revision != _revision) return false;
          if (!listEquals(remote, media.bytes)) conflicts.add(path);
        }
      }
      if (_disposed || revision != _revision) return false;
      referenceCounts = counts; conflictPaths = conflicts;
      if (reusedAudioPath != null && !found.contains(reusedAudioPath)) {
        existingPaths = found; validated = false;
        error = 'Selected stored audio no longer exists. Choose another recording.';
        return false;
      }
      for (final original in [_imageOriginal, _audioOriginal]) {
        if (original != null && counts[original] != 0) {
          existingPaths = found; validated = false;
          error = 'Original asset changed or now has references. Re-select the media and review.';
          return false;
        }
      }
      if (sharedImagePath != null && !found.contains(sharedImagePath)) {
        existingPaths = found; validated = false;
        error = 'Selected shared image no longer exists. Choose another image.';
        return false;
      }
      existingPaths = found; sameTerm = result['same_term'] == true;
      duplicate = result['duplicate'] == true; slugConflict = result['slug_conflict'] == true;
      fileConflict = conflicts.isNotEmpty; validated = true; error = null;
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
      if (!allowMissing && (!hasImage || !hasAudio)) throw StateError('Required media is missing.');
      final target = slug!, ip = imagePath;
      if (isEdit) {
        await _saveEdit(target);
        return;
      }
      final ap = audioPath!;
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
      if (reusedAudioPath != null && row.audio?.remote != true) {
        throw StateError('Selected stored audio is no longer available.');
      }
      if (sharedImagePath != null && row.image?.remote != true) {
        throw StateError('Selected shared image is no longer available.');
      }
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
      image = null; sharedImagePath = null; audio = null; reusedAudioPath = null;
      _imageRevision = null; _audioRevision = null; _imageOriginal = null; _audioOriginal = null;
      _resolutionSlug = null; imageChanged = false; audioChanged = false; allowMissing = false; schedule();
    } catch (e) { error = e.toString(); validated = false; rethrow; }
    finally { publishing = false; _notify(); }
  }
  Future<void> _saveEdit(String target) async {
    final ip = imagePath, ap = audioPath;
    final assets = VocabularyAssetService(client);
    assets.setFiles([
      if (image != null) image!.named(ip!.split('/').last),
      if (audio != null) audio!.named(ap!.split('/').last),
    ]);
    if (imageChanged && ip != null) {
      await assets.ensureUploaded(await assets.match(ip, audio:false));
    }
    if (audioChanged && ap != null) {
      await assets.ensureUploaded(await assets.match(ap, audio:true));
    }
    if (_disposed) return;
    await vocabulary.saveStudioEdit(original!, {
      'term':term.trim(), 'definition':definition.trim(), 'file_slug':target,
      'pronunciation':pronunciation.trim(), 'example':example.trim(), 'emoji':emoji.trim(),
      if (imageChanged) 'image_path':ip,
      if (audioChanged) 'audio_path':ap,
    });
    validated = false;
  }
  @override
  void dispose() { _disposed = true; _timer?.cancel(); ++_revision; super.dispose(); }
}
