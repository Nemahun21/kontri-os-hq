import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/question.dart';
import '../../models/lesson_vocab.dart';
import '../../services/lesson_vocab_service.dart';
import 'lesson_vocab_edit_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final String? initialDifficulty;
  final String? initialQuestionId;
  /// 0 = lessons, 1 = questions
  final int initialContentTab;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    this.initialDifficulty,
    this.initialQuestionId,
    this.initialContentTab = 0,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _diffCtrl;
  final LessonVocabularyService _vocabService = LessonVocabularyService();

  final Map<String, List<Map<String, dynamic>>> _questions = {
    'easy': <Map<String, dynamic>>[],
    'medium': <Map<String, dynamic>>[],
    'hard': <Map<String, dynamic>>[],
  };
  final Map<String, List<LessonVocabulary>> _lessons = {
    'easy': <LessonVocabulary>[],
    'medium': <LessonVocabulary>[],
    'hard': <LessonVocabulary>[],
  };
  final Map<String, bool> _loading = {
    'easy': true,
    'medium': true,
    'hard': true,
  };

  static const _difficulties = ['easy', 'medium', 'hard'];

  List<LessonVocabulary> _lessonsOf(String d) =>
      _lessons[d] ?? const <LessonVocabulary>[];

  List<Map<String, dynamic>> _questionsOf(String d) =>
      _questions[d] ?? const <Map<String, dynamic>>[];

  bool _isLoading(String d) => _loading[d] ?? true;

  int get _initialDiffIndex {
    final d = widget.initialDifficulty?.toLowerCase().trim();
    if (d == null || d.isEmpty) return 0;
    final i = _difficulties.indexOf(d);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _diffCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: _initialDiffIndex,
    );
    for (final d in _difficulties) {
      _loadDifficulty(d);
    }
  }

  @override
  void dispose() {
    _diffCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDifficulty(String difficulty, {bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading[difficulty] = true);
    }
    try {
      final questionsFuture = Supabase.instance.client
          .from('level_questions')
          .select(
            'level_number, position, question_id, '
            'questions(id, question, options, correct_answer_index, '
            'type, explanation, points, image_urls, type_data, '
            'scenario, wrong_consequence, cultural_context)',
          )
          .eq('category', widget.category)
          .eq('difficulty', difficulty)
          .order('level_number', ascending: true)
          .order('position', ascending: true);

      final lessonsFuture = _vocabService.getVocabulary(
        contentType: 'adventure',
        category: widget.category,
        difficulty: difficulty,
      );

      final questions = await questionsFuture;
      final lessons = await lessonsFuture;

      if (!mounted) return;
      setState(() {
        _questions[difficulty] = List<Map<String, dynamic>>.from(
          (questions as List?) ?? const [],
        );
        _lessons[difficulty] = lessons;
        _loading[difficulty] = false;
      });
    } catch (e) {
      debugPrint('load $difficulty failed: $e');
      if (mounted) {
        setState(() {
          _questions[difficulty] = _questions[difficulty] ?? [];
          _lessons[difficulty] = _lessons[difficulty] ?? [];
          _loading[difficulty] = false;
        });
      }
    }
  }

  Future<void> _addLesson(String difficulty) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonVocabEditScreen(
          initialCategory: widget.category,
          initialDifficulty: difficulty,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadDifficulty(difficulty, silent: true);
    }
  }

  Future<void> _editLesson(String difficulty, LessonVocabulary v) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LessonVocabEditScreen(existing: v)),
    );
    if (result == true && mounted) {
      await _loadDifficulty(difficulty, silent: true);
    }
  }

  Future<void> _deleteLesson(String difficulty, LessonVocabulary v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text(
          '"${v.term}" will be removed from ${widget.category} · $difficulty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _vocabService.delete(v.id);
      if (mounted) await _loadDifficulty(difficulty, silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _addQuestion(String difficulty) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(
          initialCategory: widget.category,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadDifficulty(difficulty, silent: true);
    }
  }

  Future<void> _editQuestion(
    String difficulty,
    Map<String, dynamic> row,
  ) async {
    final qRow = row['questions'];
    if (qRow is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid question data')),
      );
      return;
    }
    try {
      final question = Question.fromSupabase({
        ...qRow,
        'category': widget.category,
        'difficulty': difficulty,
        'level': row['level_number'],
      });
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditQuestionScreen(question: question),
        ),
      );
      if (result == true && mounted) {
        await _loadDifficulty(difficulty, silent: true);
      } else if (mounted) {
        await _loadDifficulty(difficulty, silent: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Edit failed: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(
    String difficulty,
    Map<String, dynamic> row,
  ) async {
    final qRow = row['questions'];
    if (qRow is! Map<String, dynamic>) return;

    final qId = qRow['id']?.toString();
    if (qId == null || qId.isEmpty) return;

    final qText = (qRow['question'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(
          '"$qText"\n\nRemoves it from all levels and deletes it permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('level_questions')
          .delete()
          .eq('question_id', qId);
      await Supabase.instance.client.from('questions').delete().eq('id', qId);
      if (mounted) await _loadDifficulty(difficulty, silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        bottom: TabBar(
          controller: _diffCtrl,
          tabs: [
            for (final d in _difficulties)
              Tab(
                text:
                    '${d[0].toUpperCase()}${d.substring(1)} (${_lessonsOf(d).length}L · ${_questionsOf(d).length}Q)',
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _diffCtrl,
        children: [
          for (final d in _difficulties)
            _DifficultyPane(
              difficulty: d,
              category: widget.category,
              loading: _isLoading(d),
              lessons: _lessonsOf(d),
              questions: _questionsOf(d),
              initialQuestionId: widget.initialQuestionId,
              initialDifficulty: widget.initialDifficulty,
              initialContentTab: widget.initialContentTab,
              onRefresh: () => _loadDifficulty(d),
              onAddLesson: () => _addLesson(d),
              onEditLesson: (v) => _editLesson(d, v),
              onDeleteLesson: (v) => _deleteLesson(d, v),
              onAddQuestion: () => _addQuestion(d),
              onEditQuestion: (row) => _editQuestion(d, row),
              onDeleteQuestion: (row) => _deleteQuestion(d, row),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// One difficulty: Lessons | Questions (separate tabs)
// ─────────────────────────────────────────────────────────────

class _DifficultyPane extends StatefulWidget {
  final String difficulty;
  final String category;
  final bool loading;
  final List<LessonVocabulary> lessons;
  final List<Map<String, dynamic>> questions;
  final String? initialQuestionId;
  final String? initialDifficulty;
  final int initialContentTab;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddLesson;
  final void Function(LessonVocabulary) onEditLesson;
  final void Function(LessonVocabulary) onDeleteLesson;
  final VoidCallback onAddQuestion;
  final void Function(Map<String, dynamic>) onEditQuestion;
  final void Function(Map<String, dynamic>) onDeleteQuestion;

  const _DifficultyPane({
    required this.difficulty,
    required this.category,
    required this.loading,
    required this.lessons,
    required this.questions,
    required this.initialQuestionId,
    required this.initialDifficulty,
    required this.initialContentTab,
    required this.onRefresh,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
    required this.onAddQuestion,
    required this.onEditQuestion,
    required this.onDeleteQuestion,
  });

  @override
  State<_DifficultyPane> createState() => _DifficultyPaneState();
}

class _DifficultyPaneState extends State<_DifficultyPane>
    with SingleTickerProviderStateMixin {
  late final TabController _contentCtrl;

  @override
  void initState() {
    super.initState();
    final openQuestions = widget.initialQuestionId != null &&
        widget.difficulty ==
            widget.initialDifficulty?.toLowerCase().trim();
    final initial = widget.initialContentTab.clamp(0, 1);
    _contentCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: openQuestions ? 1 : initial,
    );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _contentCtrl,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: [
              Tab(
                icon: const Icon(Icons.menu_book, size: 18),
                text: 'Lessons (${widget.lessons.length})',
              ),
              Tab(
                icon: const Icon(Icons.quiz, size: 18),
                text: 'Questions (${widget.questions.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _contentCtrl,
            children: [
              _LessonsTab(
                difficulty: widget.difficulty,
                category: widget.category,
                lessons: widget.lessons,
                onRefresh: widget.onRefresh,
                onAdd: widget.onAddLesson,
                onEdit: widget.onEditLesson,
                onDelete: widget.onDeleteLesson,
              ),
              _QuestionsTab(
                difficulty: widget.difficulty,
                category: widget.category,
                questions: widget.questions,
                highlightId: widget.initialQuestionId,
                onRefresh: widget.onRefresh,
                onAdd: widget.onAddQuestion,
                onEdit: widget.onEditQuestion,
                onDelete: widget.onDeleteQuestion,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lessons only
// ─────────────────────────────────────────────────────────────

class _LessonsTab extends StatelessWidget {
  final String difficulty;
  final String category;
  final List<LessonVocabulary> lessons;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final void Function(LessonVocabulary) onEdit;
  final void Function(LessonVocabulary) onDelete;

  const _LessonsTab({
    required this.difficulty,
    required this.category,
    required this.lessons,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: lessons.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.35,
                    child: Center(
                      child: Text(
                        'No lessons for $category · $difficulty',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: lessons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final v = lessons[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      title: Text(
                        v.term,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(v.definition),
                          if (v.example != null && v.example!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '"${v.example}"',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'pos ${v.position}'
                            '${v.pronunciation != null ? ' · pron' : ''}'
                            '${v.audioUrl != null ? ' · audio' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => onEdit(v),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => onDelete(v),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Questions only
// ─────────────────────────────────────────────────────────────

class _QuestionsTab extends StatelessWidget {
  final String difficulty;
  final String category;
  final List<Map<String, dynamic>> questions;
  final String? highlightId;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _QuestionsTab({
    required this.difficulty,
    required this.category,
    required this.questions,
    required this.highlightId,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: questions.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.35,
                    child: Center(
                      child: Text(
                        'No questions for $category · $difficulty',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final row = questions[i];
                  final q = row['questions'] is Map<String, dynamic>
                      ? row['questions'] as Map<String, dynamic>
                      : <String, dynamic>{};
                  final qId =
                      q['id']?.toString() ?? row['question_id']?.toString();
                  final highlighted =
                      highlightId != null && qId == highlightId;
                  final level = row['level_number'] ?? '?';
                  final position = row['position'] ?? '?';
                  final question = (q['question'] ?? '').toString();
                  final type = (q['type'] ?? '').toString();
                  final points = q['points'] ?? 0;
                  final correctIdx =
                      (q['correct_answer_index'] as num?)?.toInt() ?? 0;
                  final options = (q['options'] as List?) ?? const [];

                  return Card(
                    elevation: 0,
                    color: highlighted ? Colors.amber.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: highlighted
                            ? Colors.amber.shade700
                            : Colors.grey.shade300,
                        width: highlighted ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _badge('L$level', Colors.blue),
                              const SizedBox(width: 6),
                              _badge('Q$position', Colors.grey),
                              if (type.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _badge(type, Colors.purple),
                              ],
                              const SizedBox(width: 6),
                              _badge('$points pts', Colors.amber),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Edit',
                                icon:
                                    const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => onEdit(row),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => onDelete(row),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question.isEmpty ? '(no question text)' : question,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          if (options.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: options.asMap().entries.map((e) {
                                final idx = e.key;
                                final opt = e.value.toString();
                                final letter = String.fromCharCode(65 + idx);
                                final isCorrect = idx == correctIdx;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCorrect
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                      width: isCorrect ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$letter) $opt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isCorrect
                                          ? Colors.green.shade800
                                          : Colors.black87,
                                      fontWeight: isCorrect
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _badge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}