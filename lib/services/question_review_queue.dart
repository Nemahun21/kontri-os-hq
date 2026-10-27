import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:kohntri_os_hq/models/question.dart';

class QueuedQuestion {
  final int sourceRow;
  final int? level;
  final Difficulty? difficulty;
  final QuestionType type;
  final String scenario, question, correctText, explanation,
      wrongConsequence, culturalContext;
  final List<String> options;
  final int correctIndex;
  final int points;
  final List<String> warnings;
  const QueuedQuestion({
    required this.sourceRow, required this.level, required this.difficulty,
    required this.type, required this.scenario, required this.question,
    required this.options, required this.correctIndex,
    required this.correctText, required this.explanation,
    required this.wrongConsequence, required this.culturalContext,
    required this.points, required this.warnings,
  });
}

class ReviewQueueResult {
  final List<QueuedQuestion> items;
  final List<String> skipped;
  const ReviewQueueResult(this.items, this.skipped);
}

class ReviewQueueParser {
  static String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static ReviewQueueResult parse(Uint8List bytes) {
   var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final first = text.split('\n').first;
  final delim =
      ';'.allMatches(first).length > ','.allMatches(first).length ? ';' : ',';

  final rows = _parseCsv(text, delim);
  if (rows.isEmpty) throw const FormatException('The file is empty.');
    final header = rows.first.map((c) => norm(c.toString())).toList();
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final cLevel = col(['level']);
    final cDiff = col(['difficulty']);
    final cType = col(['question type', 'type']);
    final cScenario = col(['scenario']);
    final cQuestion = col(['question text', 'question']);
    final cOptions = col(['options']);
    final cCorrect = col(['correct option', 'correct answer']);
    final cHint = col(['hint/explanation', 'explanation', 'hint']);
    final cWrong = col(['wrong consequence']);
    final cCultural = col(['cultural context']);
    final cPoint = col(['point', 'points']);
    if (cQuestion < 0) {
      throw const FormatException('Header row must contain "Question Text".');
    }

    String cell(List row, int i) =>
        (i < 0 || i >= row.length) ? '' : row[i].toString().trim();

    final items = <QueuedQuestion>[];
    final skipped = <String>[];

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      final rowNo = r + 1;
      final q = cell(row, cQuestion);
      if (q.isEmpty) {
        skipped.add('Row $rowNo: no question text');
        continue;
      }

      final warnings = <String>[];
      final rawType = cell(row, cType).toLowerCase();
      final correctRaw = cell(row, cCorrect);
      final hasBlank = RegExp(r'_{3,}').hasMatch(q);
      var options = <String>[];
      QuestionType type;

      if (rawType.contains('true')) {
        type = QuestionType.trueFalse;
      } else {
        options = _splitOptions(cell(row, cOptions));
        if (rawType.contains('fill') && hasBlank) {
          type = options.isNotEmpty
              ? QuestionType.fillBlank : QuestionType.textInput;
        } else {
          type = options.length >= 2
              ? QuestionType.multipleChoice : QuestionType.textInput;
        }
      }

      var correctIndex = 0;
      var correctText = '';
      if (type == QuestionType.trueFalse) {
        final v = correctRaw.toLowerCase();
        if (v.startsWith('t')) {
          correctIndex = 0;
        } else if (v.startsWith('f')) {
          correctIndex = 1;
        } else {
          correctIndex = -1;
          warnings.add('Correct option "$correctRaw" is not TRUE/FALSE.');
        }
      } else if (type == QuestionType.multipleChoice) {
        correctIndex = _resolveCorrectIndex(correctRaw, options);
        if (correctIndex < 0) {
          warnings.add('Could not match correct option "$correctRaw". Select it manually.');
        }
      } else {
        correctText = correctRaw;
        if (correctRaw.isEmpty) warnings.add('No correct answer in the file.');
      }

      Difficulty? diff;
      final d = cell(row, cDiff).toLowerCase();
      for (final v in Difficulty.values) {
        if (v.name == d) diff = v;
      }
      final pts = double.tryParse(cell(row, cPoint))?.round();
      if (pts == null) warnings.add('No points in file; defaulted to 10.');

      items.add(QueuedQuestion(
        sourceRow: rowNo,
        level: int.tryParse(cell(row, cLevel)),
        difficulty: diff,
        type: type,
        scenario: cell(row, cScenario),
        question: q,
        options: options,
        correctIndex: correctIndex,
        correctText: correctText,
        explanation: cell(row, cHint),
        wrongConsequence: cell(row, cWrong),
        culturalContext: cell(row, cCultural),
        points: pts ?? 10,
        warnings: warnings,
      ));
    }
    return ReviewQueueResult(items, skipped);
  }

  /// Minimal RFC-4180 CSV parser. Handles quoted fields, embedded
/// delimiters, escaped quotes (""), and CRLF. Returns a List<List<String>>.
static List<List<String>> _parseCsv(String content, String delim) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < content.length; i++) {
    final ch = content[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == delim) {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

  // "A. x B. y C. z D. w" (inline or one per line) -> [x, y, z, w]
  static List<String> _splitLettered(String s) {
    if (!RegExp(r'^\s*A[.)]\s').hasMatch(s)) return [];
    final markers = <RegExpMatch>[];
    var from = 0;
    for (final l in ['A', 'B', 'C', 'D', 'E', 'F']) {
      final it = RegExp('(?:^|\\s)$l[.)]\\s+').allMatches(s, from);
      if (it.isEmpty) break;
      markers.add(it.first);
      from = it.first.end;
    }
    if (markers.length < 2) return [];
    return [
      for (var i = 0; i < markers.length; i++)
        s.substring(markers[i].end,
            i + 1 < markers.length ? markers[i + 1].start : s.length).trim()
    ];
  }

  static List<String> _splitOptions(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return [];
    final lettered = _splitLettered(s);
    if (lettered.isNotEmpty) return lettered;
    final lines =
        s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.length >= 2) return lines;
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static int _resolveCorrectIndex(String raw, List<String> options) {
    final c = raw.trim();
    if (c.isEmpty) return -1;
    final m = RegExp(r'^([A-Fa-f])(?:[.)]|$)').firstMatch(c);
    if (m != null) {
      final i = m.group(1)!.toUpperCase().codeUnitAt(0) - 65;
      if (i < options.length) return i;
    }
    final n = norm(c);
    for (var i = 0; i < options.length; i++) {
      if (norm(options[i]) == n) return i;
    }
    return -1;
  }
}