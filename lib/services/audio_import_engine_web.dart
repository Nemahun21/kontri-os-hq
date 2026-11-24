import 'dart:js_interop';
import 'dart:typed_data';

@JS('kontriosConvertAudio')
external JSPromise<JSUint8Array> _convertAudio(
  JSUint8Array bytes, JSString extension, JSNumber maxOutputBytes);

bool get canConvert => true;

Future<Uint8List> convert(Uint8List bytes, String extension, int maxOutputBytes) async {
  try {
    final converted = await _convertAudio(bytes.toJS, extension.toJS, maxOutputBytes.toJS).toDart;
    final output = converted.toDart;
    if (output.isEmpty || output.length > maxOutputBytes) {
      throw const FormatException('Converted audio is empty or exceeds 10 MB.');
    }
    return output;
  } catch (error) {
    throw FormatException('Chrome audio conversion failed: $error. '
      'If the engine is missing, run scripts/setup-web-audio.ps1 from HQ and restart Chrome. '
      'Otherwise check the recording format and try again.');
  }
}
