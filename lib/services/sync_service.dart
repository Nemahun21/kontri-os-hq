import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:path/path.dart' as path;

class SyncService {
  final _pendingService = PendingOperationService();
  final _supabase = Supabase.instance.client;

  Future<void> syncPendingOperations() async {
    final operations = await _pendingService.getPendingOperations();
    if (operations.isEmpty) return;

    for (var op in operations) {
      try {
        final tableName = op['table_name'];
        final operation = op['operation'];
        final data = jsonDecode(op['data']) as Map<String, dynamic>;
        final mediaJson = op['media'] != null
            ? jsonDecode(op['media']) as Map<String, dynamic>?
            : null;

        // Upload media if any
        Map<String, String>? uploadedUrls;
        if (mediaJson != null) {
          uploadedUrls = await _uploadMedia(
            mediaJson.cast<String, String>(),
            tableName,
          );
          // Merge URLs into data
          if (uploadedUrls['image'] != null) {
            data['image_url'] = uploadedUrls['image'];
          }
          if (uploadedUrls['audio'] != null) {
            data['audio_url'] = uploadedUrls['audio'];
          }
          // For daily challenge, fields are image_url and audio_url
          // For language questions, they're the same
        }

        switch (operation) {
          case 'insert':
            await _supabase.from(tableName).insert(data);
            break;
          case 'update':
            final id = data['id'];
            await _supabase.from(tableName).update(data).eq('id', id);
            break;
          case 'delete':
            final id = data['id'];
            await _supabase.from(tableName).delete().eq('id', id);
            break;
          default:
            break;
        }

        // Cleanup local media files
        if (mediaJson != null) {
          for (var path in mediaJson.values) {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }

        await _pendingService.deleteOperation(op['id']);
      } catch (e) {
        print('Sync error: $e');
        // Keep the operation in queue and retry later
      }
    }
  }

  Future<Map<String, String>> _uploadMedia(
    Map<String, String> media,
    String tableName,
  ) async {
    final result = <String, String>{};

    // Determine buckets
    String imageBucket, audioBucket;
    switch (tableName) {
      case 'questions':
        imageBucket = 'question_images';
        audioBucket = 'question_audio';
        break;
      case 'daily_challenge_questions':
        imageBucket = 'daily_challenge_images';
        audioBucket = 'daily_challenge_audio';
        break;
      case 'language_questions':
        imageBucket = 'language_question_images';
        audioBucket = 'language_question_audio';
        break;
      case 'daily_nuggets':
        imageBucket = 'daily_nugget_images';
        audioBucket = ''; // no audio for nuggets
        break;
      default:
        return result;
    }

    if (media.containsKey('image')) {
      final file = File(media['image']!);
      if (await file.exists()) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
          final bytes = await file.readAsBytes();
          await _supabase.storage
              .from(imageBucket)
              .uploadBinary(fileName, bytes);
          final publicUrl = _supabase.storage
              .from(imageBucket)
              .getPublicUrl(fileName);
          result['image'] = publicUrl;
        } catch (e) {
          print('Image upload failed: $e');
        }
      }
    }
    if (media.containsKey('audio')) {
      final file = File(media['audio']!);
      if (await file.exists()) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
          final bytes = await file.readAsBytes();
          await _supabase.storage
              .from(audioBucket)
              .uploadBinary(fileName, bytes);
          final publicUrl = _supabase.storage
              .from(audioBucket)
              .getPublicUrl(fileName);
          result['audio'] = publicUrl;
        } catch (e) {
          print('Audio upload failed: $e');
        }
      }
    }
    return result;
  }
}
