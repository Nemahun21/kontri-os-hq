import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxSheet {
  final String name;
  final List<List<String>> rows;
  XlsxSheet(this.name, this.rows);
}

/// Minimal .xlsx reader. Ignores styles/number formats entirely.
class XlsxReader {
  static List<XlsxSheet> read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? find(String path) {
      for (final f in archive.files) {
        if (f.name == path) return f;
      }
      return null;
    }

    String text(ArchiveFile f) => utf8.decode(f.content as List<int>);

    // Shared strings
    final shared = <String>[];
    final ssFile = find('xl/sharedStrings.xml');
    if (ssFile != null) {
      final doc = XmlDocument.parse(text(ssFile));
      for (final si in doc.findAllElements('si')) {
        final buf = StringBuffer();
        for (final t in si.findAllElements('t')) {
          final p = t.parent;
          if (p is XmlElement && p.name.local == 'rPh') continue;
          buf.write(t.innerText);
        }
        shared.add(buf.toString());
      }
    }

    // Workbook -> sheet names and relationship ids
    final wbFile = find('xl/workbook.xml');
    final relFile = find('xl/_rels/workbook.xml.rels');
    if (wbFile == null || relFile == null) {
      throw const FormatException('Not a valid .xlsx file.');
    }

    final targets = <String, String>{};
    for (final r in XmlDocument.parse(text(relFile)).findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) targets[id] = target;
    }

    final result = <XlsxSheet>[];
    for (final s in XmlDocument.parse(text(wbFile)).findAllElements('sheet')) {
      if (s.getAttribute('state') == 'hidden' ||
          s.getAttribute('state') == 'veryHidden') {
        continue;
      }
      final name = s.getAttribute('name') ?? 'Sheet';
      String? rid;
      for (final a in s.attributes) {
        if (a.name.local == 'id') rid = a.value;
      }
      final target = rid == null ? null : targets[rid];
      if (target == null) continue;
      final path =
          target.startsWith('/') ? target.substring(1) : 'xl/$target';
      final sheetFile = find(path);
      if (sheetFile == null) continue;

      final rows = _parseSheet(text(sheetFile), shared);
      if (rows.isNotEmpty) result.add(XlsxSheet(name, rows));
    }
    return result;
  }

  static List<List<String>> _parseSheet(String xml, List<String> shared) {
    final doc = XmlDocument.parse(xml);
    final rows = <List<String>>[];

    for (final row in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var fallbackCol = 0;
      for (final c in row.findAllElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref != null ? _colIndex(ref) : fallbackCol;
        fallbackCol = col + 1;

        final type = c.getAttribute('t');
        final vEl = c.getElement('v');
        final v = vEl?.innerText ?? '';
        String value;

        if (type == 's') {
          final i = int.tryParse(v);
          value = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
        } else if (type == 'inlineStr') {
          value = c.findAllElements('t').map((t) => t.innerText).join();
        } else if (type == 'b') {
          value = v == '1' ? 'TRUE' : 'FALSE';
        } else if (type == 'str' || type == 'e') {
          value = v;
        } else {
          final d = double.tryParse(v);
          value = (d != null && d == d.truncateToDouble() && d.abs() < 1e15)
              ? d.toInt().toString()
              : v;
        }
        cells[col] = value.trim();
      }
      if (cells.values.every((v) => v.isEmpty)) continue;
      final maxCol = cells.keys.reduce((a, b) => a > b ? a : b);
      rows.add([for (var i = 0; i <= maxCol; i++) cells[i] ?? '']);
    }
    return rows;
  }

  static int _colIndex(String ref) {
    var n = 0;
    for (final code in ref.codeUnits) {
      if (code >= 65 && code <= 90) {
        n = n * 26 + (code - 64);
      } else if (code >= 97 && code <= 122) {
        n = n * 26 + (code - 96);
      } else {
        break;
      }
    }
    return n - 1;
  }

  /// Merges the chosen sheets into one CSV. Repeated header rows are dropped.
  static Uint8List toCsv(List<XlsxSheet> sheets) {
    final lines = <String>[];
    List<String>? header;
    for (final sheet in sheets) {
      for (var i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (header == null) {
          header = row;
        } else if (i == 0 && _sameRow(row, header)) {
          continue;
        }
        lines.add(row.map(_escape).join(','));
      }
    }
    return Uint8List.fromList(utf8.encode(lines.join('\n')));
  }

  static bool _sameRow(List<String> a, List<String> b) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) return false;
    }
    return true;
  }

  static String _escape(String s) =>
      (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r'))
          ? '"${s.replaceAll('"', '""')}"'
          : s;
}