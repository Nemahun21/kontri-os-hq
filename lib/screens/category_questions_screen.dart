import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/widgets/question_table.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/models/question.dart'; 


class CategoryQuestionsScreen extends StatelessWidget {
  final String category;
  const CategoryQuestionsScreen({super.key, required this.category});

  Color _getColor() {
    switch (category) {
      case 'History': return Colors.brown;
      case 'Sports': return Colors.indigo;
      case 'Places': return Colors.teal;
      case 'Food': return Colors.red;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = QuestionService();
    final cacheService = CacheService();

    return FutureBuilder<Set<String>>(
      future: PendingOperationService().getPendingIdsForTable('questions'),
      builder: (context, snapshot) {
        final pendingIds = snapshot.data ?? {};
        return QuestionTable(
          title: category,
          accentColor: _getColor(),
          cacheKey: 'questions_category_$category',
          pendingIds: pendingIds,
          initialCategory: category,
          fetchQuestions: () => service.getQuestionsByCategory(category),
          saveQuestion: (q) async {
            final online = await ConnectivityHelper.isOnline();
            if (online) {
              if (q.id.isEmpty) {
                await service.addQuestion(q);
              } else {
                await service.updateQuestion(q);
              }
            } else {
              await PendingOperationService().enqueue(
                'questions',
                q.id.isEmpty ? 'insert' : 'update',
                q.toSupabase()..remove('id'),
              );

              // Update local cache immediately
              final cacheKey = 'questions_category_$category';
              final cached = await cacheService.getList<Question>(cacheKey, Question.fromSupabase);
              final newList = [q, ...cached];
              await cacheService.set(cacheKey, newList.map((q) => q.toSupabase()).toList());
            }
            return true;
          },
          deleteQuestion: (id) async {
            final online = await ConnectivityHelper.isOnline();
            if (online) {
              await service.deleteQuestion(id);
            } else {
              await PendingOperationService().enqueue(
                'questions',
                'delete',
                {'id': id},
              );

              // Remove from cache locally
              final cacheKey = 'questions_category_$category';
              final cached = await cacheService.getList<Question>(cacheKey, Question.fromSupabase);
              final newList = cached.where((q) => q.id != id).toList();
              await cacheService.set(cacheKey, newList.map((q) => q.toSupabase()).toList());
            }
            return true;
          },
        );
      },
    );
  }
}