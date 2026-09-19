import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:kohntri_os_hq/services/pending_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionTable extends StatefulWidget {
  final Future<List<Question>> Function() fetchQuestions;
  final Future<bool> Function(Question) saveQuestion; // for add/update
  final Future<bool> Function(String) deleteQuestion;
  final String title;
  final Color accentColor;
  final String cacheKey;
  final List<String>?
  columnLabels; // e.g., ['Position', 'Difficulty', 'Type', ...]
  final Set<String>? pendingIds;
  final String? initialCategory;
  final String? initialLanguageId;
  final String? initialThemeId;

  const QuestionTable({
    super.key,
    required this.fetchQuestions,
    required this.saveQuestion,
    required this.deleteQuestion,
    required this.title,
    required this.accentColor,
    required this.cacheKey,
    this.columnLabels,
    this.pendingIds,
    this.initialCategory,
    this.initialLanguageId, // 👈
    this.initialThemeId,
  });

  @override
  State<QuestionTable> createState() => _QuestionTableState();
}

class _QuestionTableState extends State<QuestionTable> {
  List<Question> _questions = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<List<Question>> _getCachedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(widget.cacheKey);
    if (json == null) return [];
    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => Question.fromSupabase(item)).toList();
  }

  Future<void> _saveCachedQuestions(List<Question> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(questions.map((q) => q.toSupabase()).toList());
    await prefs.setString(widget.cacheKey, json);
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await widget.fetchQuestions();
      setState(() {
        _questions = questions;
        _isLoading = false;
        _isOffline = false;
      });
      await _saveCachedQuestions(questions);
    } catch (e) {
      final cached = await _getCachedQuestions();
      if (cached.isNotEmpty) {
        setState(() {
          _questions = cached;
          _isLoading = false;
          _isOffline = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using cached data – network unavailable.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openEditor({Question? existing}) {
    final type = existing?.type ?? QuestionType.multipleChoice;
    if (type == QuestionType.imageChoice ||
        type == QuestionType.dragAndDrop ||
        type == QuestionType.fillBlank ||
        type == QuestionType.matchPairs ||
        type == QuestionType.audioGuess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditQuestionScreen(
            question: existing,
            initialCategory: existing?.category,
             initialLanguageId: widget.initialLanguageId,  // 👈
          initialThemeId: widget.initialThemeId, 
          ),
        ),
      ).then((_) => _loadQuestions());
      return;
    }
    _openSimpleDialog(existing: existing);
  }

  Future<void> _openSimpleDialog({Question? existing}) async {
    final result = await showDialog<Question>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SimpleQuestionDialog(
        category: existing?.category ?? '',
        existing: existing,
      ),
    );
    if (result != null) {
      bool success;
      if (existing != null) {
        final updated = Question(
          id: existing.id,
          question: result.question,
          options: result.options,
          correctAnswerIndex: result.correctAnswerIndex,
          category: existing.category,
          explanation: result.explanation,
          type: result.type,
          points: result.points,
          difficulty: result.difficulty,
          level: result.level,
          imageUrls: existing.imageUrls,
          typeData: existing.typeData,
        );
        success = await widget.saveQuestion(updated);
      } else {
        success = await widget.saveQuestion(result);
      }
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Question added!' : 'Question updated!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadQuestions();
      }
    }
  }

  void _addQuestion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(
          initialCategory: widget.initialCategory,
          initialLanguageId: widget.initialLanguageId, // 👈 pass through
          initialThemeId: widget.initialThemeId,
        ),
      ),
    ).then((_) => _loadQuestions());
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final success = await widget.deleteQuestion(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadQuestions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuestion,
        child: const Icon(Icons.add),
        tooltip: 'Add new question',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _isOffline
                        ? 'No cached data. Connect to network to load.'
                        : 'No questions yet.',
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildHeaderRow(),
                      ..._questions.map((q) => _buildDataRow(q)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderRow() {
    final labels =
        widget.columnLabels ??
        const [
          'Level',
          'Difficulty',
          'Type',
          'Questions',
          'Options',
          'Correct',
          'Explanation',
          'Scenario', // new
          'Consequence', // new
          'Cultural Context', // new
          'Points',
          'Actions',
        ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              labels[0],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              labels[1],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              labels[2],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              labels[3],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              labels[4],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              labels[5],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              labels[6],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // ---- new columns ----
          SizedBox(
            width: 120,
            child: Text(
              labels[7],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              labels[8],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              labels[9],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // ----
          SizedBox(
            width: 60,
            child: Text(
              labels[10],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              labels[11],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(Question q) {
    final hasPending = widget.pendingIds?.contains(q.id) ?? false;
    return GestureDetector(
      onTap: () => _openEditor(existing: q),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            SizedBox(width: 50, child: Text(q.level?.toString() ?? '—')),
            SizedBox(width: 90, child: Text(q.difficulty.name)),
            SizedBox(width: 100, child: Text(q.type.displayName)),
            SizedBox(
              width: 130,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      q.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasPending) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.sync, size: 16, color: Colors.orange),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 130,
              child: Text(
                q.options.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                q.options.isNotEmpty ? q.options[q.correctAnswerIndex] : '—',
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                q.explanation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ---- new columns ----
            SizedBox(
              width: 120,
              child: Text(
                q.scenario ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                q.wrongConsequence ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                q.culturalContext ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ----
            SizedBox(width: 60, child: Text('${q.points}')),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _openEditor(existing: q),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteQuestion(q.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Simple Question Dialog ----------
class _SimpleQuestionDialog extends StatefulWidget {
  final String category;
  final Question? existing;
  const _SimpleQuestionDialog({required this.category, this.existing});

  @override
  State<_SimpleQuestionDialog> createState() => _SimpleQuestionDialogState();
}

class _SimpleQuestionDialogState extends State<_SimpleQuestionDialog> {
  late TextEditingController _questionController;
  late TextEditingController _optionsController;
  late TextEditingController _explanationController;
  late TextEditingController _pointsController;
  late TextEditingController _levelController;
  late Difficulty _selectedDifficulty;
  late QuestionType _selectedType;
  late int _correctAnswerIndex;
  late List<String> _optionsList;
  late TextEditingController _scenarioController;
  late TextEditingController _wrongConsequenceController;
  late TextEditingController _culturalContextController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _questionController = TextEditingController(text: existing?.question ?? '');
    _optionsController = TextEditingController(
      text: existing?.options.join(', ') ?? '',
    );
    _explanationController = TextEditingController(
      text: existing?.explanation ?? '',
    );
    _pointsController = TextEditingController(
      text: (existing?.points ?? 10).toString(),
    );
    _levelController = TextEditingController(
      text: (existing?.level ?? 1).toString(),
    );
    _selectedDifficulty = existing?.difficulty ?? Difficulty.medium;
    _selectedType = existing?.type ?? QuestionType.multipleChoice;
    _correctAnswerIndex = existing?.correctAnswerIndex ?? 0;
    _optionsList = existing?.options ?? [];
    _scenarioController = TextEditingController(text: existing?.scenario ?? '');
    _wrongConsequenceController = TextEditingController(
      text: existing?.wrongConsequence ?? '',
    );
    _culturalContextController = TextEditingController(
      text: existing?.culturalContext ?? '',
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionsController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    _levelController.dispose();
    _scenarioController.dispose();
    _wrongConsequenceController.dispose();
    _culturalContextController.dispose();
    super.dispose();
  }

  void _save() {
    final options = _optionsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (options.isEmpty && _selectedType != QuestionType.textInput) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Options cannot be empty.')));
      return;
    }
    if (_selectedType != QuestionType.textInput &&
        _correctAnswerIndex >= options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correct answer index out of range.')),
      );
      return;
    }
    final points = int.tryParse(_pointsController.text) ?? 10;
    final level = int.tryParse(_levelController.text) ?? 1;
    final question = Question(
      id: widget.existing?.id ?? '',
      question: _questionController.text.trim(),
      options: _selectedType == QuestionType.textInput ? [] : options,
      correctAnswerIndex: _selectedType == QuestionType.textInput
          ? 0
          : _correctAnswerIndex,
      category: widget.category,
      explanation: _explanationController.text.trim(),
      type: _selectedType,
      points: points,
      difficulty: _selectedDifficulty,
      level: level,
      imageUrls: widget.existing?.imageUrls,
      typeData: widget.existing?.typeData,
      scenario: _scenarioController.text.trim().isEmpty
          ? null
          : _scenarioController.text.trim(),
      wrongConsequence: _wrongConsequenceController.text.trim().isEmpty
          ? null
          : _wrongConsequenceController.text.trim(),
      culturalContext: _culturalContextController.text.trim().isEmpty
          ? null
          : _culturalContextController.text.trim(),
    );
    Navigator.pop(context, question);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _levelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Level'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Difficulty>(
                value: _selectedDifficulty,
                items: Difficulty.values.map((d) {
                  return DropdownMenuItem(value: d, child: Text(d.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedDifficulty = val!),
                decoration: const InputDecoration(labelText: 'Difficulty'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<QuestionType>(
                value: _selectedType,
                items:
                    [
                      QuestionType.multipleChoice,
                      QuestionType.trueFalse,
                      QuestionType.textInput,
                    ].map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      );
                    }).toList(),
                onChanged: (val) => setState(() {
                  _selectedType = val!;
                  if (_selectedType == QuestionType.trueFalse) {
                    _optionsController.text = 'True, False';
                  } else if (_selectedType == QuestionType.textInput) {
                    _optionsController.text = '';
                  }
                  _correctAnswerIndex = 0;
                }),
                decoration: const InputDecoration(labelText: 'Question Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _questionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Question Text'),
              ),
              const SizedBox(height: 8),
              if (_selectedType != QuestionType.textInput)
                TextFormField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma separated)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_selectedType != QuestionType.textInput) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _correctAnswerIndex < _optionsList.length
                      ? _correctAnswerIndex
                      : null,
                  items: _optionsList.asMap().entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.key + 1}: ${entry.value}'),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _correctAnswerIndex = val!),
                  decoration: const InputDecoration(
                    labelText: 'Correct Option',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _explanationController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Explanation / Hint',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _scenarioController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Scenario (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _wrongConsequenceController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Wrong Consequence (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _culturalContextController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Cultural Context (optional)',
                ),
              ),
              TextFormField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditQuestionScreen(
                    question: widget.existing,
                    initialCategory: widget.category,
                  ),
                ),
              );
            },
            child: const Text('Advanced Edit'),
          ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
