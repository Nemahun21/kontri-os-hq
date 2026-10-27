import 'dart:convert';

import 'package:csv/csv.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/services/daily_content_service.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:path/path.dart' as path;
import 'package:file_selector/file_selector.dart';

class DailyContentCsvImporter extends StatefulWidget {
  final ContentType contentType;
  const DailyContentCsvImporter({super.key, required this.contentType});

  @override
  State<DailyContentCsvImporter> createState() =>
      _DailyContentCsvImporterState();
}

class _DailyContentCsvImporterState extends State<DailyContentCsvImporter> {
  final DailyContentService _service = DailyContentService();

  List<String> _columns = [];
  List<Map<String, String>> _rows = [];
  String? _fileName;
  int _addedCount = 0;
  bool _isParsing = false;
  bool _isAdding = false;
  int _basePosition = 1;

  @override
  void initState() {
    super.initState();
    _loadBasePosition();
  }

 Future<void> _loadBasePosition() async {
  try {
    final items = await _service.getAll(widget.contentType);
    if (items.isEmpty) {
      _basePosition = 1;
      print('📌 _basePosition = 1 (table empty)');
      return;
    }

    final maxPos = items
        .map((e) => (e['position'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    _basePosition = maxPos + 1;
    print('📌 _basePosition = $_basePosition (max=$maxPos, rows=${items.length})');
  } catch (e) {
    print('⚠️ Could not load base position: $e');
    _basePosition = 1;
  }
}
  // ---------- Pick + parse ----------

 Future<void> _pickCsv() async {
  setState(() {
    _isParsing = true;
    _columns = [];
    _rows = [];
    _addedCount = 0;
  });

  await _loadBasePosition();

  try {
    const typeGroup = XTypeGroup(
      label: 'CSV',
      extensions: ['csv'],
      mimeTypes: [
        'text/csv',
        'text/comma-separated-values',
        'application/octet-stream',
      ],
    );

    final picked = await openFile(acceptedTypeGroups: [typeGroup]);
    if (picked == null) return;

    final name = picked.name;
    final bytes = await picked.readAsBytes();

    final ext = path.extension(name).toLowerCase();
    if (ext != '.csv') {
      _snack('Please pick a CSV file. If you have an Excel file, '
          'open it in Excel and use File → Save As → CSV UTF-8.');
      return;
    }

    var content = utf8.decode(bytes, allowMalformed: true);
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    List<List<dynamic>> parsed = csv.decode(content);

    if (parsed.isEmpty) {
      _snack('File is empty.');
      return;
    }

    parsed = parsed.where((row) {
      return row.any((cell) => cell.toString().trim().isNotEmpty);
    }).toList();

    if (parsed.isEmpty) {
      _snack('File is empty.');
      return;
    }

    final rawHeader = parsed.first.map((e) => e.toString().trim()).toList();
    final header = rawHeader.map((e) => e.toLowerCase()).toList();

    final dataRows = <Map<String, String>>[];
    for (var i = 1; i < parsed.length; i++) {
      final raw = parsed[i];
      if (raw.isEmpty) continue;

      final map = <String, String>{};
      for (var j = 0; j < header.length; j++) {
        final key = header[j];
        if (key.isEmpty) continue;
        map[key] = j < raw.length ? raw[j].toString().trim() : '';
      }
      dataRows.add(map);
    }

    final columnsWithData = header
        .where((h) => h.isNotEmpty)
        .where((h) => dataRows.any((row) => (row[h] ?? '').isNotEmpty))
        .toList();

    if (!mounted) return;
    setState(() {
      _fileName = name;
      _columns = columnsWithData;
      _rows = dataRows;
    });
    _snack('${dataRows.length} rows parsed.');
  } catch (e) {
    _snack('Parse failed: $e');
  } finally {
    if (mounted) setState(() => _isParsing = false);
  }
}
  
  Map<String, dynamic> _buildData(Map<String, String> row, int index) {
    final data = <String, dynamic>{};

    final parsedPos = int.tryParse((row['position'] ?? '').trim());
    final hasExplicit = parsedPos != null && parsedPos > 0;
    data['position'] = hasExplicit ? parsedPos : (_basePosition + index);
    
    // Image URL
    final img = (row['image_url'] ?? '').trim();
    if (img.isNotEmpty) data['image_url'] = img;

    switch (widget.contentType) {
      case ContentType.proverb:
        data['text'] = (row['text'] ?? row['proverb'] ?? '').trim();
        data['meaning'] = (row['meaning'] ?? '').trim();
        data['source'] = (row['source'] ?? '').trim();
        break;

      case ContentType.funFact:
        data['text'] = (row['text'] ?? row['fact'] ?? '').trim();
        data['detail'] = (row['detail'] ?? '').trim();
        break;

      case ContentType.challenge:
        data['question'] = (row['question'] ?? '').trim();
        final optsRaw = row['options'] ?? '';
        final opts = optsRaw
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        data['options'] = opts;
        data['correct_answer_index'] =
            int.tryParse(row['correct_answer_index'] ?? '') ?? 0;
        data['points'] = int.tryParse(row['points'] ?? '') ?? 10;
        data['explanation'] = (row['explanation'] ?? '').trim();
        break;
    }

    return data;
  }

  Future<void> _saveRow(Map<String, String> row, int index) async {
    final data = _buildData(row, index);
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      await _service.create(widget.contentType, data);
    } else {
      await PendingOperationService().enqueue(
        _service.tableNameForType(widget.contentType),
        'insert',
        data,
      );
    }
  }

  Future<void> _addRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];

    try {
      await _saveRow(row, index);
      _basePosition++;
      if (!mounted) return;
      setState(() {
        _rows.removeAt(index);
        _addedCount++;
      });
      _snack('Added #$_addedCount');
    } catch (e) {
      _snack('Add failed: $e');
    }
  }

  Future<void> _addAll() async {
    if (_rows.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);

    final remaining = List<Map<String, String>>.from(_rows);
    var added = 0;

    for (final row in remaining) {
      try {
        await _saveRow(row, 0);
        _basePosition++;
        added++;
        if (!mounted) return;
        setState(() {
          _rows.remove(row);
          _addedCount++;
        });
      } catch (e) {
        debugPrint('❌ Row failed: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isAdding = false);
    _snack('$added rows added.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Labels ----------

  String _typeLabel() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return 'Proverbs';
      case ContentType.funFact:
        return 'Interesting Factss';
      case ContentType.challenge:
        return 'Challenge Questions';
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import CSV → ${_typeLabel()}'),
        actions: [
          if (_rows.isNotEmpty)
            TextButton.icon(
              onPressed: _isAdding ? null : _addAll,
              icon: _isAdding
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.playlist_add, color: Colors.white),
              label: Text(
                'Add All (${_rows.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(_fileName ?? 'No file selected'),
                subtitle: _columns.isEmpty
                    ? const Text('Tap to pick a CSV or Excelfile')
                    : Text(
                        '${_columns.length} columns • ${_rows.length} rows left • $_addedCount added',
                      ),
                trailing: _isParsing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isParsing ? null : _pickCsv,
              ),
            ),
          ),
          if (_columns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _columns
                    .map(
                      (c) => Chip(
                        label: Text(c),
                        labelStyle: const TextStyle(fontSize: 11),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child: Text(
                      'No rows to add.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final row = _rows[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._columns.map((col) {
                                final value = row[col] ?? '';
                                if (value.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF2C3E50),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '$col: ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        TextSpan(text: value),
                                      ],
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _addRow(i),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A5276),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
