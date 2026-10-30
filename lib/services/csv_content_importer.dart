import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/daily_challenge_question.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';

enum CsvImportMode { adventure, daily, language }

class CsvQuestionImporter extends StatefulWidget {
  final CsvImportMode mode;

  // Defaults applied to every CSV row.
  final String? category;
  final Difficulty? difficulty;
  final String? languageId;
  final String? themeId;
  final int? startingPosition;
  final String? dailyChallengeId;

  const CsvQuestionImporter({
    super.key,
    required this.mode,
    this.category,
    this.difficulty,
    this.languageId,
    this.themeId,
    this.startingPosition,
    this.dailyChallengeId,
  });

  @override
  State<CsvQuestionImporter> createState() => _CsvQuestionImporterState();
}

class _CsvQuestionImporterState extends State<CsvQuestionImporter> {
  final _questionService = QuestionService();
  final _dailyService = DailyChallengeService();
  final _langService = LanguageQuestionService();

  List<String> _columns = [];
  List<Map<String, String>> _rows = [];
  String? _fileName;
  int _addedCount = 0;
  bool _isParsing = false;
  bool _isAdding = false;

  // ---------- Pick + parse ----------
Future<void> _pickCsv() async {
  setState(() {
    _isParsing = true;
    _columns = [];
    _rows = [];
    _addedCount = 0;
  });

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('File bytes are null.');
      return;
    }

    // Step 1 — decode bytes to text
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      _snack('UTF-8 decode failed: $e');
      return;
    }

    // Normalise line endings
    content = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Strip BOM if present
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    print('📄 First 200 chars: ${content.substring(0, content.length > 200 ? 200 : content.length)}');

    // Step 2 — decode CSV
    List<List<dynamic>> parsed;
    try {
      parsed = csv.decode(content);
    } catch (e) {
      _snack('CSV decode failed: $e');
      return;
    }

    if (parsed.isEmpty) {
      _snack('CSV is empty.');
      return;
    }

    final header = parsed.first
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final dataRows = <Map<String, String>>[];
    for (var i = 1; i < parsed.length; i++) {
      final raw = parsed[i];
      if (raw.isEmpty) continue;
      final map = <String, String>{};
      for (var j = 0; j < header.length; j++) {
        map[header[j]] = j < raw.length ? raw[j].toString().trim() : '';
      }
      dataRows.add(map);
    }

    if (!mounted) return;
    setState(() {
      _fileName = file.name;
      _columns = header;
      _rows = dataRows;
    });
    _snack('${dataRows.length} rows parsed.');
  } catch (e) {
    _snack('Parse failed: $e');
  } finally {
    if (mounted) setState(() => _isParsing = false);
  }
}
  List<String> _splitOptions(String raw) {
    if (raw.trim().isEmpty) return [];
    // Accept | ; or , as separators. Prefer | if present.
    if (raw.contains('|')) return raw.split('|').map((e) => e.trim()).toList();
    if (raw.contains(';')) return raw.split(';').map((e) => e.trim()).toList();
    return raw.split(',').map((e) => e.trim()).toList();
  }

  int _parseInt(String? v, int fallback) =>
      int.tryParse((v ?? '').trim()) ?? fallback;

  QuestionType _parseType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return QuestionType.multipleChoice;
    final t = raw.trim();
    for (final value in QuestionType.values) {
      if (value.name.toLowerCase() == t.toLowerCase() ||
          value.displayName.toLowerCase() == t.toLowerCase()) {
        return value;
      }
    }
    return QuestionType.multipleChoice;
  }

  Difficulty _parseDifficulty(String? raw) {
    if (raw == null || raw.trim().isEmpty) return Difficulty.medium;
    final d = raw.trim().toLowerCase();
    switch (d) {
      case 'easy':
        return Difficulty.easy;
      case 'hard':
        return Difficulty.hard;
      default:
        return Difficulty.medium;
    }
  }

  Question _buildAdventureQuestion(Map<String, String> row, int index) {
    final questionText = row['question'] ?? '';
    final options = _splitOptions(row['options'] ?? '');
    final correct = _parseInt(row['correct_answer_index'], 0);
    final type = _parseType(row['type']);

    return Question(
      id: '',
      question: questionText,
      options: options,
      correctAnswerIndex: correct,
      category: (row['category']?.isNotEmpty ?? false)
          ? row['category']!
          : (widget.category ?? 'Uncategorized'),
      explanation: row['explanation'] ?? '',
      type: type,
      imageUrls: null,
      points: _parseInt(row['points'], 10),
      difficulty: (row['difficulty']?.isNotEmpty ?? false)
          ? _parseDifficulty(row['difficulty'])
          : (widget.difficulty ?? Difficulty.medium),
      typeData: null,
      scenario: (row['scenario']?.isNotEmpty ?? false) ? row['scenario'] : null,
      wrongConsequence: (row['wrong_consequence']?.isNotEmpty ?? false)
          ? row['wrong_consequence']
          : null,
      culturalContext: (row['cultural_context']?.isNotEmpty ?? false)
          ? row['cultural_context']
          : null,
    );
  }

  DailyChallengeQuestion _buildDailyQuestion(
    Map<String, String> row,
    int index,
  ) {
    final basePosition = widget.startingPosition ?? 1;
    return DailyChallengeQuestion(
      id: '',
      dailyChallengeId: widget.dailyChallengeId ??
          DailyChallengeService.activeDailyChallengeId,
          category: (row['category']?.isNotEmpty ?? false)
        ? row['category']!
        :_defaultCategory(),
      question: row['question'] ?? '',
      options: _splitOptions(row['options'] ?? ''),
      correctAnswerIndex: _parseInt(row['correct_answer_index'], 0),
      questionType: row['question_type'] ?? row['type'] ?? 'multipleChoice',
      imageUrl: null,
      audioUrl: null,
      explanation: row['explanation'] ?? '',
      points: _parseInt(row['points'], 10),
      position: _parseInt(row['position'], basePosition + index),
      trimStart: 0.0,
      trimEnd: 0.0,
    );
  }

  String _defaultCategory() {
  switch (widget.mode) {
    case CsvImportMode.daily:
      return 'Daily Challenge';
    case CsvImportMode.language:
      return widget.languageId ?? 'Languages';
    case CsvImportMode.adventure:
      return widget.category ?? 'Uncategorized';
  }
}

  LanguageQuestion _buildLanguageQuestion(
    Map<String, String> row,
    int index,
  ) {
    final basePosition = widget.startingPosition ?? 1;
    return LanguageQuestion(
      id: '',
      languageTypeId: widget.languageId ?? '',
      themeId: widget.themeId ?? '',
      question: row['question'] ?? '',
      options: _splitOptions(row['options'] ?? ''),
      correctAnswerIndex: _parseInt(row['correct_answer_index'], 0),
      type: row['type'] ?? 'multipleChoice',
      explanation: row['explanation'] ?? '',
      points: _parseInt(row['points'], 10),
      position: _parseInt(row['position'], basePosition + index),
      imageUrl: null,
      audioUrl: null,
      trimStart: 0.0,
      trimEnd: 0.0,
      createdAt: null,
      typeData: null,
    );
  }

  Future<void> _saveRow(Map<String, String> row, int index) async {
    switch (widget.mode) {
      case CsvImportMode.adventure:
        await _questionService.addQuestion(
          _buildAdventureQuestion(row, index),
        );
        break;
      case CsvImportMode.daily:
        await _dailyService.addQuestion(
          _buildDailyQuestion(row, index),
        );
        break;
      case CsvImportMode.language:
        if (widget.languageId == null || widget.themeId == null) {
          throw Exception('Language and theme are required for language import.');
        }
        await _langService.addQuestion(
          _buildLanguageQuestion(row, index),
        );
        break;
    }
  }

  // ---------- Add a single row ----------

  Future<void> _addRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];

    try {
      await _saveRow(row, index);
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

  // ---------- Add all ----------

  Future<void> _addAll() async {
    if (_rows.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);

    final remaining = List<Map<String, String>>.from(_rows);
    var added = 0;
    var position = 0;

    for (final row in remaining) {
      try {
        await _saveRow(row, position);
        added++;
        position++;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (widget.mode) {
      CsvImportMode.adventure => 'Adventure Questions',
      CsvImportMode.daily => 'Daily Challenge Questions',
      CsvImportMode.language => 'Language Questions',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Import CSV → $modeLabel'),
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
                    ? const Text('Tap to pick a CSV file')
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
                    .map((c) => Chip(
                          label: Text(c),
                          labelStyle: const TextStyle(fontSize: 11),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
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
                                    backgroundColor:
                                        const Color(0xFF1A5276),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20),
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