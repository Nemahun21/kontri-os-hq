import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../models/vocabulary_import_batch.dart';

Future<List<VocabularyLocalAsset>?> pickIntakeFolder(Set<String> extensions) async {
  final path = await getDirectoryPath();
  if (path == null) return null;
  final files = <VocabularyLocalAsset>[];
  await for (final item in Directory(path).list(recursive: true, followLinks: false)) {
    if (item is! File) continue;
    final name = item.uri.pathSegments.last;
    if (!extensions.contains(name.split('.').last.toLowerCase())) continue;
    files.add(VocabularyLocalAsset(name, item.length, item.readAsBytes));
  }
  return files;
}
