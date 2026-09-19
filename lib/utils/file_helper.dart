import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileHelper {
  static Future<String?> copyToLocal(File source, String prefix) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(source.path)}';
      final dest = File(path.join(dir.path, fileName));
      await source.copy(dest.path);
      return dest.path;
    } catch (e) {
      print('Copy error: $e');
      return null;
    }
  }
}