import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/widgets/question_table.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/models/question.dart';

class CategoryQuestionsScreen extends StatefulWidget {
  final String category;
  const CategoryQuestionsScreen({super.key, required this.category});

  @override
  State<CategoryQuestionsScreen> createState() =>
      _CategoryQuestionsScreenState();
}

class _CategoryQuestionsScreenState extends State<CategoryQuestionsScreen> {
  final QuestionService _service = QuestionService();
  final CacheService _cacheService = CacheService();

  String _selectedDifficulty = 'easy';
  Map<String, int> _counts = {'easy': 0, 'medium': 0, 'hard': 0};

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    try {
      final all = await _service.getQuestionsByCategory(widget.category);
      if (!mounted) return;
      setState(() {
        _counts = {
          'easy': all.where((q) => q.difficulty.name == 'easy').length,
          'medium': all.where((q) => q.difficulty.name == 'medium').length,
          'hard': all.where((q) => q.difficulty.name == 'hard').length,
        };
      });
    } catch (e) {
      debugPrint('Count error: $e');
    }
  }

  Color _getColor() {
    switch (widget.category) {
      case 'History':
        return Colors.brown;
      case 'Sports':
        return Colors.indigo;
      case 'Places':
        return Colors.teal;
      case 'Food':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return FutureBuilder<Set<String>>(
      future: PendingOperationService().getPendingIdsForTable('questions'),
      builder: (context, snapshot) {
        final pendingIds = snapshot.data ?? {};
        return QuestionTable(
          key: ValueKey('${widget.category}_$_selectedDifficulty'),
          title: widget.category,
          accentColor: color,
          cacheKey:
              'questions_category_${widget.category}_$_selectedDifficulty',
          pendingIds: pendingIds,
          initialCategory: widget.category,
          headerWidget: _buildDifficultyTabs(),
          fetchQuestions: () async {
            final all =
                await _service.getQuestionsByCategory(widget.category);
            return all
                .where((q) => q.difficulty.name == _selectedDifficulty)
                .toList();
          },
          saveQuestion: (q) async {
            final online = await ConnectivityHelper.isOnline();
            if (online) {
              if (q.id.isEmpty) {
                await _service.addQuestion(q);
              } else {
                await _service.updateQuestion(q);
              }
            } else {
              await PendingOperationService().enqueue(
                'questions',
                q.id.isEmpty ? 'insert' : 'update',
                q.toSupabase()..remove('id'),
              );

              final cacheKey =
                  'questions_category_${widget.category}_$_selectedDifficulty';
              final cached = await _cacheService.getList<Question>(
                cacheKey,
                Question.fromSupabase,
              );
              final newList = [q, ...cached];
              await _cacheService.set(
                cacheKey,
                newList.map((q) => q.toSupabase()).toList(),
              );
            }
            await _refreshCounts();
            return true;
          },
          deleteQuestion: (id) async {
            final online = await ConnectivityHelper.isOnline();
            if (online) {
              await _service.deleteQuestion(id);
            } else {
              await PendingOperationService().enqueue(
                'questions',
                'delete',
                {'id': id},
              );

              final cacheKey =
                  'questions_category_${widget.category}_$_selectedDifficulty';
              final cached = await _cacheService.getList<Question>(
                cacheKey,
                Question.fromSupabase,
              );
              final newList = cached.where((q) => q.id != id).toList();
              await _cacheService.set(
                cacheKey,
                newList.map((q) => q.toSupabase()).toList(),
              );
            }
            await _refreshCounts();
            return true;
          },
        );
      },
    );
  }

  Widget _buildDifficultyTabs() {
    final tabs = [
      {'key': 'easy', 'label': '💡 Easy', 'color': Colors.green},
      {'key': 'medium', 'label': '🔥 Medium', 'color': Colors.orange},
      {'key': 'hard', 'label': '🌊 Hard', 'color': Colors.blue},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: tabs.map((d) {
          final key = d['key'] as String;
          final label = d['label'] as String;
          final tabColor = d['color'] as Color;
          final isSelected = _selectedDifficulty == key;
          final count = _counts[key] ?? 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tabColor.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? tabColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? tabColor : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? tabColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}