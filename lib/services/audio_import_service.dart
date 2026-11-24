import 'dart:typed_data';
import '../models/vocabulary_import_batch.dart';
import 'vocabulary_asset_service.dart';
import 'audio_import_engine_stub.dart'
    if (dart.library.io) 'audio_import_engine_io.dart'
    if (dart.library.js_interop) 'audio_import_engine_web.dart' as engine;

typedef AudioConverter = Future<Uint8List> Function(Uint8List bytes, String extension, int maxOutputBytes);

/// The input may vary; the publish contract is always MP3.
class AudioImportService {
  static const extensions = ['mp3','wav','m4a','aac','ogg','opus','flac','amr','3gp'];
  static const maxSourceBytes = 50 * 1024 * 1024;
  static bool get canConvert => engine.canConvert;
  static List<String> get selectableExtensions => canConvert ? extensions : const ['mp3'];

  static Future<Uint8List> prepare(VocabularyLocalAsset source, {AudioConverter? converter}) async {
    final extension = source.name.split('.').last.toLowerCase();
    if (!source.name.contains('.') || !extensions.contains(extension)) {
      throw const FormatException('Unsupported audio format. Choose MP3, WAV, M4A, AAC, OGG, OPUS, FLAC, AMR or 3GP.');
    }
    final max = VocabularyAssetService.maxAudioBytes;
    final size = await source.length();
    if (size <= 0 || size > (extension == 'mp3' ? max : maxSourceBytes)) {
      throw const FormatException('Invalid audio size. MP3: 10 MB maximum; other sources: 50 MB maximum.');
    }
    final bytes = await source.read();
    if (bytes.length != size) throw const FormatException('Audio changed while reading.');
    final output = extension == 'mp3' ? bytes :
        await (converter ?? engine.convert)(bytes, extension, max);
    if (output.isEmpty || output.length > max ||
        !VocabularyAssetService.validSignature('audio.mp3', output)) {
      throw const FormatException('Invalid MP3 output or output exceeds 10 MB.');
    }
    return output;
  }
}
