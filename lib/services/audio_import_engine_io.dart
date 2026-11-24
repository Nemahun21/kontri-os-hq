import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

bool get canConvert => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// No shell, no external URLs, no original-file modification. All files are
/// isolated in a unique local temporary directory and removed after conversion.
Future<Uint8List> convert(Uint8List bytes, String extension, int maxOutputBytes) async {
  if (!canConvert) {
    throw UnsupportedError('Automatic conversion requires desktop HQ. Use MP3 on this platform.');
  }
  if (!const ['wav','m4a','aac','ogg','opus','flac','amr','3gp'].contains(extension)) {
    throw const FormatException('Unsupported conversion input.');
  }
  final dir = await Directory.systemTemp.createTemp('kontrios_audio_');
  Process? process;
  try {
    final input = File(p.join(dir.path, 'input.$extension'));
    final output = File(p.join(dir.path, 'output.mp3'));
    await input.writeAsBytes(bytes, flush: true);
    try {
      process = await Process.start('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-nostdin', '-xerror',
        '-protocol_whitelist', 'file',
        '-format_whitelist', 'wav,mov,mp4,m4a,3gp,3g2,mj2,aac,ogg,flac,amr,mp3',
        '-i', input.path,
        '-map', '0:a:0', '-vn', '-sn', '-dn',
        '-map_metadata', '-1', '-map_chapters', '-1',
        '-ac', '1', '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', '96k',
        // Permit a small overshoot, then reject rather than publish a truncated clip.
        '-fs', (maxOutputBytes + 65536).toString(), '-f', 'mp3', '-y', output.path,
      ], runInShell: false);
    } on ProcessException {
      throw StateError('FFmpeg could not start. Install FFmpeg and restart HQ. Windows: winget install --id Gyan.FFmpeg --exact');
    }
    final running = process!;
    final stdoutDone = running.stdout.drain<void>();
    final stderrDone = running.stderr.drain<void>();
    int exitCode;
    try {
      exitCode = await running.exitCode.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      running.kill(ProcessSignal.sigkill);
      await running.exitCode;
      throw const FormatException('Audio conversion timed out. Use a shorter recording.');
    } finally {
      await Future.wait<void>([stdoutDone, stderrDone]);
    }
    if (exitCode != 0 || !await output.exists()) {
      throw const FormatException('Audio conversion failed. File may be corrupt or its codec is unsupported by FFmpeg.');
    }
    final length = await output.length();
    if (length <= 0 || length > maxOutputBytes) {
      throw const FormatException('Converted audio exceeds 10 MB or contains no data.');
    }
    return await output.readAsBytes();
  } finally {
    try { await dir.delete(recursive: true); } on FileSystemException {
      // Cleanup failure must not hide the original conversion error.
    }
  }
}
