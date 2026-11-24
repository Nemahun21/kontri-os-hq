import 'dart:typed_data';

enum ImportState { ready, missing, existing, conflict, saved, failed }

/// Read one selected file at a time; no media bytes are retained in a batch.
class VocabularyLocalAsset {
  final String name;
  final Future<int> Function() length;
  final Future<Uint8List> Function() read;
  const VocabularyLocalAsset(this.name, this.length, this.read);
}

class VocabularyAssetMatch {
  final String path;
  final VocabularyLocalAsset? local;
  final bool remote;
  const VocabularyAssetMatch(this.path, {this.local, this.remote = false});
  bool get available => local != null || remote;
}

class VocabularyImportRow {
  final int line;
  final Map<String, dynamic> data;
  final List<String> issues = [];
  ImportState state = ImportState.ready;
  VocabularyAssetMatch? image;
  VocabularyAssetMatch? audio;
  String? existingId;
  String? existingImage;
  String? existingAudio;
  String? error;
  bool get hasMissing => (image == null || !image!.available) ||
      (data['content_type'] == 'language' && (audio == null || !audio!.available));

  VocabularyImportRow(this.line, this.data);
  void conflict(String issue) {
    issues.add(issue);
    state = ImportState.conflict;
  }
}

class VocabularyImportBatch {
  final String name;
  final List<VocabularyImportRow> rows;
  VocabularyImportBatch(this.name, this.rows);
  int count(ImportState state) => rows.where((r) => r.state == state).length;
}
