import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vocabulary_import_batch.dart';
import 'vocabulary_asset_service.dart';

class VocabularyImportService {
  final SupabaseClient client;
  final VocabularyAssetService assets;
  VocabularyImportService(this.client, this.assets);

  static bool validSlug(String value) =>
      RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(value);
  static String key(String value) => value.trim().toLowerCase();
  static String suggestedSlug(String language, String term, String meaning) {
    String part(String value) {
      var text = key(value);
      const replacements = {'ŋ':'ng','ə':'e','ɛ':'e','ō':'o','ɔ':'o','ʌ':'a'};
      for (final entry in replacements.entries) {
        text = text.replaceAll(entry.key, entry.value);
      }
      return text.replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+
  static String? optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// TXT uses the same CSV header, with comma or tab delimiter.
  static List<Map<String, String>> parse(Uint8List bytes, {bool txt = false}) {
    var content = utf8.decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (content.startsWith('\uFEFF')) content = content.substring(1);
    if (content.trim().isEmpty) throw const FormatException('No content.');
    final delimiter = txt && content.split('\n').first.contains('\t') ? '\t' : ',';
    final records = CsvToListConverter(
      fieldDelimiter: delimiter, eol: '\n', shouldParseNumbers: false,
      allowInvalid: false,
    ).convert(content);
    if (records.isEmpty) throw const FormatException('No rows.');
    final header = records.first.map((v) => key(v.toString())).toList();
    if (header.toSet().length != header.length || header.any((v) => v.isEmpty)) {
      throw const FormatException('Blank or duplicate column header.');
    }
    if (!(header.contains('term') || header.contains('word')) ||
        !(header.contains('definition') || header.contains('translation'))) {
      throw const FormatException('Required headers: term, definition.');
    }
    final rows = <Map<String, String>>[];
    for (var i = 1; i < records.length; i++) {
      final cells = records[i];
      if (cells.every((v) => v.toString().trim().isEmpty)) continue;
      if (cells.length != header.length) {
        throw FormatException('Record ${i + 1} has ${cells.length} fields; expected ${header.length}.');
      }
      rows.add({for (var j = 0; j < header.length; j++) header[j]: cells[j].toString().trim()});
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _all(String table, String columns) async {
    final results = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      final page = await client.from(table).select(columns).order('id').range(offset, offset + 499);
      results.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < 500) break;
    }
    return results;
  }

  static String identity(Map<String, dynamic> row) =>
      '${key(row['term'].toString())}\u0000${key(row['definition'].toString())}';
  static String scope(Map<String, dynamic> row) =>
      row['content_type'] == 'language'
          ? 'language:${row['theme_id']}'
          : 'adventure:${row['category']}:${row['difficulty']}';

  Future<VocabularyImportBatch> prepare(String name, List<Map<String, String>> source, {
    required String contentType, String? initialThemeId, String? initialCategory,
    String initialDifficulty = 'easy',
    void Function(int done, int total)? progress,
  }) async {
    final languages = await _all('language_type', 'id,name,code');
    final themes = await _all('language_themes', 'id,language_type_id,name');
    final existing = await _all('lesson_vocabulary',
        'id,content_type,category,theme_id,difficulty,term,definition,file_slug,image_url,audio_url');
    final languageById = {for (final l in languages) l['id']: l};
    final themeById = {for (final t in themes) t['id']: t};
    final byScope = <String, List<Map<String, dynamic>>>{};
    final bySlug = <String, List<Map<String, dynamic>>>{};
    for (final row in existing) {
      (byScope[scope(row)] ??= []).add(row);
      final slug = row['file_slug'];
      if (slug is String) (bySlug[slug] ??= []).add(row);
    }
    final batchKeys = <String, VocabularyImportRow>{};
    final batchInputs = <String, Map<String, String>>{};
    final batchSlugs = <String, VocabularyImportRow>{};
    final rows = <VocabularyImportRow>[];
    for (var i = 0; i < source.length; i++) {
      final input = source[i];
      String val(String field) => input[field] ?? '';
      final data = <String, dynamic>{
        'content_type': contentType,
        'term': optional(val('term')) ?? val('word'),
        'definition': optional(val('definition')) ?? val('translation'),
        'pronunciation': optional(val('pronunciation')),
        'example': optional(val('example')),
        'emoji': optional(val('emoji')),
        'file_slug': optional(val('file_slug')),
      };
      final row = VocabularyImportRow(i + 2, data);
      rows.add(row);
      try {
        if (data['term'] == '' || data['definition'] == '') {
          throw const FormatException('Term and definition are required.');
        }
        final positionText = optional(val('position'));
        if (positionText != null) {
          final position = int.tryParse(positionText);
          if (position == null || position < 1) throw const FormatException('Position must be a positive integer.');
          data['position'] = position;
        }
        if (contentType == 'language') {
          final languageText = key(val('language'));
          final themeText = key(val('theme'));
          Map<String, dynamic>? target;
          if (languageText.isEmpty && themeText.isEmpty && initialThemeId != null) {
            // Legacy files without both fields are scoped to the open theme.
            target = themeById[initialThemeId];
          } else {
            if (languageText.isEmpty || themeText.isEmpty) {
              throw const FormatException('Specify both language and theme.');
            }
            final lang = languages.where((l) =>
                key(l['code'].toString()) == languageText ||
                key(l['name'].toString()) == languageText).toList();
            if (lang.length != 1) throw const FormatException('Unknown or ambiguous language.');
            final matches = themes.where((t) =>
                t['language_type_id'] == lang.single['id'] &&
                key(t['name'].toString()) == themeText).toList();
            if (matches.length != 1) throw const FormatException('Unknown or ambiguous theme; create it separately.');
            target = matches.single;
          }
          if (target == null) throw const FormatException('Theme is required.');
          final lang = languageById[target['language_type_id']];
          if (lang == null) throw const FormatException('Theme has no language.');
          data['theme_id'] = target['id'];
          data['language_code'] = lang['code'];
          // Existing legacy manifests can recover the exact stored slug.
          final same = (byScope[scope(data)] ?? []).where((e) => identity(e) == identity(data)).toList();
          if (same.length > 1) throw const FormatException('Ambiguous existing vocabulary.');
          if (data['file_slug'] == null && same.length == 1) data['file_slug'] = same.single['file_slug'];
          if (data['file_slug'] == null) {
            // Legacy text-only manifests can still add a record. Never invent a
            // collision suffix; an ambiguous slug needs a founder-supplied key.
            data['file_slug'] = suggestedSlug(lang['code'].toString(), data['term'].toString(), data['definition'].toString());
          }
          final slug = data['file_slug'] as String?;
          if (slug == null || !validSlug(slug) || slug.length > 180 ||
              !slug.startsWith('${lang['code']}_')) {
            throw const FormatException('A valid language-prefixed file_slug is required for new language rows.');
          }
          for (final e in bySlug[slug] ?? const <Map<String, dynamic>>[]) {
            if (identity(e) != identity(data)) {
              throw const FormatException('Slug belongs to a different existing term or meaning.');
            }
          }
          final priorSlug = batchSlugs[slug];
          if (priorSlug != null && identity(priorSlug.data) != identity(data)) {
            priorSlug.conflict('Slug reused for different vocabulary.');
            throw const FormatException('Slug reused for different vocabulary.');
          }
          batchSlugs[slug] = row;
        } else {
          const categories = ['History', 'Food', 'Places', 'Sports'];
          final category = optional(val('category')) ?? initialCategory;
          final matches = categories.where((c) => key(c) == key(category ?? '')).toList();
          final difficulty = key(optional(val('difficulty')) ?? initialDifficulty);
          if (matches.length != 1 || !['easy','medium','hard'].contains(difficulty)) {
            throw const FormatException('Valid Adventure category and difficulty are required.');
          }
          data['category'] = matches.single;
          data['difficulty'] = difficulty;
          data['file_slug'] = null;
        }

        final siblings = byScope[scope(data)] ?? const <Map<String, dynamic>>[];
        final matches = siblings.where((e) =>
            identity(e) == identity(data) ||
            (data['file_slug'] != null && e['file_slug'] == data['file_slug'])).toList();
        if (matches.length > 1) throw const FormatException('Ambiguous existing record.');
        if (matches.isNotEmpty) {
          final old = matches.single;
          if (identity(old) != identity(data) ||
              (old['file_slug'] != null && old['file_slug'] != data['file_slug'])) {
            throw const FormatException('Existing record conflicts; edit it explicitly.');
          }
          row.existingId = old['id'].toString();
          row.existingImage = optional(old['image_url'] as String?);
          row.existingAudio = optional(old['audio_url'] as String?);
        }

        final batchKey = '${scope(data)}:${identity(data)}';
        final previous = batchKeys[batchKey];
        if (previous != null) {
          final priorInput = batchInputs[batchKey]!;
          if (input.length == priorInput.length &&
              input.entries.every((e) => priorInput[e.key] == e.value)) {
            row.state = ImportState.existing;
            row.issues.add('Exact duplicate in manifest; skipped.');
            progress?.call(i + 1, source.length);
            continue;
          }
          previous.conflict('Conflicting duplicate in manifest; review both.');
          throw const FormatException('Conflicting duplicate in manifest; review both.');
        }
        batchKeys[batchKey] = row;
        batchInputs[batchKey] = input;
        // Images need an explicit concept mapping. No definition guessing.
        final imageRef = optional(val('image_url')) ?? optional(val('image'));
        if (imageRef != null) {
          row.image = await assets.match(imageRef, audio: false);
        }
        final audioRef = optional(val('audio_url'));
        if (audioRef != null || contentType == 'language') {
          final expected = contentType == 'language'
              ? 'audio/${data['language_code']}/${data['file_slug']}.mp3'
              : null;
          final reference = audioRef ?? expected!;
          row.audio = await assets.match(reference, audio: true);
          if (expected != null && row.audio!.path != expected) {
            throw const FormatException('Audio must use this vocabulary slug and language.');
          }
        }
        final imageSupplied = imageRef != null;
        final audioSupplied = audioRef != null;
        if (imageSupplied && row.image?.available != true) row.issues.add('Explicit image file missing.');
        if (audioSupplied && row.audio?.available != true) row.issues.add('Explicit audio file missing.');
        if (row.existingImage != null && row.image != null &&
            client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.image!.path) != row.existingImage) {
          throw const FormatException('Image would replace an existing link. Edit explicitly.');
        }
        if (row.existingAudio != null && row.audio != null &&
            (audioSupplied || row.audio!.available) &&
            client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.audio!.path) != row.existingAudio) {
          throw const FormatException('Audio would replace an existing link. Edit explicitly.');
        }
        final missingImage = row.existingImage == null && row.image?.available != true;
        final missingAudio = contentType == 'language' && row.existingAudio == null && row.audio?.available != true;
        if (missingImage || missingAudio || row.issues.isNotEmpty) {
          row.state = ImportState.missing;
          if (missingImage) row.issues.add('No image available.');
          if (missingAudio) row.issues.add('No audio available.');
        } else if (row.existingId != null && row.existingImage != null &&
            (contentType != 'language' || row.existingAudio != null) &&
            row.image?.local == null && row.audio?.local == null) {
          row.state = ImportState.existing;
        }
      } catch (e) {
        row.conflict(e.toString());
      }
      progress?.call(i + 1, source.length);
    }
    return VocabularyImportBatch(name, rows);
  }

  /// Re-select the same manifest after interruption. The DB and exact object
  /// paths are authoritative checkpoints; never skip a row by a local counter.
  Future<void> commit(VocabularyImportBatch batch, {required bool allowMissing,
      required Future<void> Function(List<Map<String, dynamic>>) save,
      required void Function() progress, bool Function()? cancelled}) async {
    final ready = batch.rows.where((r) => r.state == ImportState.ready ||
        (allowMissing && r.state == ImportState.missing)).toList();
    const chunkSize = 25;
    for (var start = 0; start < ready.length; start += chunkSize) {
      if (cancelled?.call() == true) break;
      final pending = <VocabularyImportRow>[];
      final payload = <Map<String, dynamic>>[];
      for (final row in ready.skip(start).take(chunkSize)) {
        if (cancelled?.call() == true) break;
        try {
          final data = Map<String, dynamic>.from(row.data);
          for (final entry in {'image':row.image,'audio':row.audio}.entries) {
            final match = entry.value;
            if (match?.available == true) {
              await assets.ensureUploaded(match!);
              data['${entry.key}_path'] = match.path;
            }
          }
          pending.add(row);
          payload.add(data);
        } catch (e) {
          row.state = ImportState.failed;
          row.error = e.toString();
        }
        progress();
      }
      if (payload.isEmpty) continue;
      try {
        await save(payload);
        for (final row in pending) {
          row.state = ImportState.saved;
        }
      } catch (e) {
        for (final row in pending) {
          row.state = ImportState.failed;
          row.error = 'Database batch rolled back or response uncertain: $e. Re-scan before retrying.';
        }
      }
      progress();
    }
  }
}
), '');
    }
    final t = part(term), m = part(meaning);
    if (t.isEmpty || m.isEmpty) throw const FormatException('Supply a valid explicit file_slug.');
    return '${language}_${t}_${m}';
  }
  static String? optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// TXT uses the same CSV header, with comma or tab delimiter.
  static List<Map<String, String>> parse(Uint8List bytes, {bool txt = false}) {
    var content = utf8.decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (content.startsWith('\uFEFF')) content = content.substring(1);
    if (content.trim().isEmpty) throw const FormatException('No content.');
    final delimiter = txt && content.split('\n').first.contains('\t') ? '\t' : ',';
    final records = CsvToListConverter(
      fieldDelimiter: delimiter, eol: '\n', shouldParseNumbers: false,
      allowInvalid: false,
    ).convert(content);
    if (records.isEmpty) throw const FormatException('No rows.');
    final header = records.first.map((v) => key(v.toString())).toList();
    if (header.toSet().length != header.length || header.any((v) => v.isEmpty)) {
      throw const FormatException('Blank or duplicate column header.');
    }
    if (!(header.contains('term') || header.contains('word')) ||
        !(header.contains('definition') || header.contains('translation'))) {
      throw const FormatException('Required headers: term, definition.');
    }
    final rows = <Map<String, String>>[];
    for (var i = 1; i < records.length; i++) {
      final cells = records[i];
      if (cells.every((v) => v.toString().trim().isEmpty)) continue;
      if (cells.length != header.length) {
        throw FormatException('Record ${i + 1} has ${cells.length} fields; expected ${header.length}.');
      }
      rows.add({for (var j = 0; j < header.length; j++) header[j]: cells[j].toString().trim()});
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _all(String table, String columns) async {
    final results = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      final page = await client.from(table).select(columns).order('id').range(offset, offset + 499);
      results.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < 500) break;
    }
    return results;
  }

  static String identity(Map<String, dynamic> row) =>
      '${key(row['term'].toString())}\u0000${key(row['definition'].toString())}';
  static String scope(Map<String, dynamic> row) =>
      row['content_type'] == 'language'
          ? 'language:${row['theme_id']}'
          : 'adventure:${row['category']}:${row['difficulty']}';

  Future<VocabularyImportBatch> prepare(String name, List<Map<String, String>> source, {
    required String contentType, String? initialThemeId, String? initialCategory,
    String initialDifficulty = 'easy',
    void Function(int done, int total)? progress,
  }) async {
    final languages = await _all('language_type', 'id,name,code');
    final themes = await _all('language_themes', 'id,language_type_id,name');
    final existing = await _all('lesson_vocabulary',
        'id,content_type,category,theme_id,difficulty,term,definition,file_slug,image_url,audio_url');
    final languageById = {for (final l in languages) l['id']: l};
    final themeById = {for (final t in themes) t['id']: t};
    final byScope = <String, List<Map<String, dynamic>>>{};
    final bySlug = <String, List<Map<String, dynamic>>>{};
    for (final row in existing) {
      (byScope[scope(row)] ??= []).add(row);
      final slug = row['file_slug'];
      if (slug is String) (bySlug[slug] ??= []).add(row);
    }
    final batchKeys = <String, VocabularyImportRow>{};
    final batchInputs = <String, Map<String, String>>{};
    final batchSlugs = <String, VocabularyImportRow>{};
    final rows = <VocabularyImportRow>[];
    for (var i = 0; i < source.length; i++) {
      final input = source[i];
      String val(String field) => input[field] ?? '';
      final data = <String, dynamic>{
        'content_type': contentType,
        'term': optional(val('term')) ?? val('word'),
        'definition': optional(val('definition')) ?? val('translation'),
        'pronunciation': optional(val('pronunciation')),
        'example': optional(val('example')),
        'emoji': optional(val('emoji')),
        'file_slug': optional(val('file_slug')),
      };
      final row = VocabularyImportRow(i + 2, data);
      rows.add(row);
      try {
        if (data['term'] == '' || data['definition'] == '') {
          throw const FormatException('Term and definition are required.');
        }
        final positionText = optional(val('position'));
        if (positionText != null) {
          final position = int.tryParse(positionText);
          if (position == null || position < 1) throw const FormatException('Position must be a positive integer.');
          data['position'] = position;
        }
        if (contentType == 'language') {
          final languageText = key(val('language'));
          final themeText = key(val('theme'));
          Map<String, dynamic>? target;
          if (languageText.isEmpty && themeText.isEmpty && initialThemeId != null) {
            // Legacy files without both fields are scoped to the open theme.
            target = themeById[initialThemeId];
          } else {
            if (languageText.isEmpty || themeText.isEmpty) {
              throw const FormatException('Specify both language and theme.');
            }
            final lang = languages.where((l) =>
                key(l['code'].toString()) == languageText ||
                key(l['name'].toString()) == languageText).toList();
            if (lang.length != 1) throw const FormatException('Unknown or ambiguous language.');
            final matches = themes.where((t) =>
                t['language_type_id'] == lang.single['id'] &&
                key(t['name'].toString()) == themeText).toList();
            if (matches.length != 1) throw const FormatException('Unknown or ambiguous theme; create it separately.');
            target = matches.single;
          }
          if (target == null) throw const FormatException('Theme is required.');
          final lang = languageById[target['language_type_id']];
          if (lang == null) throw const FormatException('Theme has no language.');
          data['theme_id'] = target['id'];
          data['language_code'] = lang['code'];
          // Existing legacy manifests can recover the exact stored slug.
          final same = (byScope[scope(data)] ?? []).where((e) => identity(e) == identity(data)).toList();
          if (same.length > 1) throw const FormatException('Ambiguous existing vocabulary.');
          if (data['file_slug'] == null && same.length == 1) data['file_slug'] = same.single['file_slug'];
          if (data['file_slug'] == null) {
            // Legacy text-only manifests can still add a record. Never invent a
            // collision suffix; an ambiguous slug needs a founder-supplied key.
            data['file_slug'] = suggestedSlug(lang['code'].toString(), data['term'].toString(), data['definition'].toString());
          }
          final slug = data['file_slug'] as String?;
          if (slug == null || !validSlug(slug) || slug.length > 180 ||
              !slug.startsWith('${lang['code']}_')) {
            throw const FormatException('A valid language-prefixed file_slug is required for new language rows.');
          }
          for (final e in bySlug[slug] ?? const <Map<String, dynamic>>[]) {
            if (identity(e) != identity(data)) {
              throw const FormatException('Slug belongs to a different existing term or meaning.');
            }
          }
          final priorSlug = batchSlugs[slug];
          if (priorSlug != null && identity(priorSlug.data) != identity(data)) {
            priorSlug.conflict('Slug reused for different vocabulary.');
            throw const FormatException('Slug reused for different vocabulary.');
          }
          batchSlugs[slug] = row;
        } else {
          const categories = ['History', 'Food', 'Places', 'Sports'];
          final category = optional(val('category')) ?? initialCategory;
          final matches = categories.where((c) => key(c) == key(category ?? '')).toList();
          final difficulty = key(optional(val('difficulty')) ?? initialDifficulty);
          if (matches.length != 1 || !['easy','medium','hard'].contains(difficulty)) {
            throw const FormatException('Valid Adventure category and difficulty are required.');
          }
          data['category'] = matches.single;
          data['difficulty'] = difficulty;
          data['file_slug'] = null;
        }

        final siblings = byScope[scope(data)] ?? const <Map<String, dynamic>>[];
        final matches = siblings.where((e) =>
            identity(e) == identity(data) ||
            (data['file_slug'] != null && e['file_slug'] == data['file_slug'])).toList();
        if (matches.length > 1) throw const FormatException('Ambiguous existing record.');
        if (matches.isNotEmpty) {
          final old = matches.single;
          if (identity(old) != identity(data) ||
              (old['file_slug'] != null && old['file_slug'] != data['file_slug'])) {
            throw const FormatException('Existing record conflicts; edit it explicitly.');
          }
          row.existingId = old['id'].toString();
          row.existingImage = optional(old['image_url'] as String?);
          row.existingAudio = optional(old['audio_url'] as String?);
        }

        final batchKey = '${scope(data)}:${identity(data)}';
        final previous = batchKeys[batchKey];
        if (previous != null) {
          previous.conflict('Repeated row in manifest; keep one.');
          throw const FormatException('Repeated row in manifest; keep one.');
        }
        batchKeys[batchKey] = row;
        // Images need an explicit concept mapping. No definition guessing.
        final imageRef = optional(val('image_url')) ?? optional(val('image'));
        if (imageRef != null) {
          row.image = await assets.match(imageRef, audio: false);
        }
        final audioRef = optional(val('audio_url'));
        if (audioRef != null || contentType == 'language') {
          final expected = contentType == 'language'
              ? 'audio/${data['language_code']}/${data['file_slug']}.mp3'
              : null;
          final reference = audioRef ?? expected!;
          row.audio = await assets.match(reference, audio: true);
          if (expected != null && row.audio!.path != expected) {
            throw const FormatException('Audio must use this vocabulary slug and language.');
          }
        }
        final imageSupplied = imageRef != null;
        final audioSupplied = audioRef != null;
        if (imageSupplied && row.image?.available != true) row.issues.add('Explicit image file missing.');
        if (audioSupplied && row.audio?.available != true) row.issues.add('Explicit audio file missing.');
        if (row.existingImage != null && row.image != null &&
            client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.image!.path) != row.existingImage) {
          throw const FormatException('Image would replace an existing link. Edit explicitly.');
        }
        if (row.existingAudio != null && row.audio != null &&
            (audioSupplied || row.audio!.available) &&
            client.storage.from(VocabularyAssetService.bucket).getPublicUrl(row.audio!.path) != row.existingAudio) {
          throw const FormatException('Audio would replace an existing link. Edit explicitly.');
        }
        final missingImage = row.existingImage == null && row.image?.available != true;
        final missingAudio = contentType == 'language' && row.existingAudio == null && row.audio?.available != true;
        if (missingImage || missingAudio || row.issues.isNotEmpty) {
          row.state = ImportState.missing;
          if (missingImage) row.issues.add('No image available.');
          if (missingAudio) row.issues.add('No audio available.');
        } else if (row.existingId != null && row.existingImage != null &&
            (contentType != 'language' || row.existingAudio != null) &&
            row.image?.local == null && row.audio?.local == null) {
          row.state = ImportState.existing;
        }
      } catch (e) {
        row.conflict(e.toString());
      }
      progress?.call(i + 1, source.length);
    }
    return VocabularyImportBatch(name, rows);
  }

  /// Re-select the same manifest after interruption. The DB and exact object
  /// paths are authoritative checkpoints; never skip a row by a local counter.
  Future<void> commit(VocabularyImportBatch batch, {required bool allowMissing,
      required Future<void> Function(List<Map<String, dynamic>>) save,
      required void Function() progress, bool Function()? cancelled}) async {
    final ready = batch.rows.where((r) => r.state == ImportState.ready ||
        (allowMissing && r.state == ImportState.missing)).toList();
    const chunkSize = 25;
    for (var start = 0; start < ready.length; start += chunkSize) {
      if (cancelled?.call() == true) break;
      final pending = <VocabularyImportRow>[];
      final payload = <Map<String, dynamic>>[];
      for (final row in ready.skip(start).take(chunkSize)) {
        if (cancelled?.call() == true) break;
        try {
          final data = Map<String, dynamic>.from(row.data);
          for (final entry in {'image':row.image,'audio':row.audio}.entries) {
            final match = entry.value;
            if (match?.available == true) {
              await assets.ensureUploaded(match!);
              data['${entry.key}_path'] = match.path;
            }
          }
          pending.add(row);
          payload.add(data);
        } catch (e) {
          row.state = ImportState.failed;
          row.error = e.toString();
        }
        progress();
      }
      if (payload.isEmpty) continue;
      try {
        await save(payload);
        for (final row in pending) {
          row.state = ImportState.saved;
        }
      } catch (e) {
        for (final row in pending) {
          row.state = ImportState.failed;
          row.error = 'Database batch rolled back or response uncertain: $e. Re-scan before retrying.';
        }
      }
      progress();
    }
  }
}
