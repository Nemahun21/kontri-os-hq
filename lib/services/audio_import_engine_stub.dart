import 'dart:typed_data';

bool get canConvert => false;
Future<Uint8List> convert(Uint8List bytes, String extension, int maxOutputBytes) async {
  throw UnsupportedError('Automatic conversion requires desktop HQ with FFmpeg installed. Use MP3 on this platform.');
}
