import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/widgets/question_table.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';

class ThemeQuestionsScreen extends StatelessWidget {
  final String themeId;
  final String themeName;
  final String languageName;
  final String languageId;

  const ThemeQuestionsScreen({
    super.key,
    required this.themeId,
    required this.themeName,
    required this.languageName,
    required this.languageId,
  });

  @override
  Widget build(BuildContext context) {
    final service = LanguageQuestionService();
    return FutureBuilder<Set<String>>(
      future: PendingOperationService().getPendingIdsForTable(
        'language_questions',
      ),
      builder: (context, snapshot) {
        final pendingIds = snapshot.data ?? {};
        return QuestionTable(
          title: '$languageName - $themeName',
          accentColor: Colors.purple,
          cacheKey: 'lang_$themeId',
          pendingIds: pendingIds,
          initialCategory: 'Languages', // 👈
          initialLanguageId: languageId, // 👈
          initialThemeId: themeId,
          languageMode: true,
          fetchQuestions: () async {
            final langQuestions = await service.getQuestionsForTheme(themeId);
            return langQuestions.map((lq) => lq.toQuestion()).toList();
          },
          saveQuestion: (q) async {
            final online = await ConnectivityHelper.isOnline();
            final all = await service.getQuestionsForTheme(themeId);
            int position;
            if (q.id.isNotEmpty) {
              final existing = all.firstWhere(
                (lq) => lq.id == q.id,
                orElse: () => all.first,
              );
              position = existing.position;
            } else {
              final maxPos = all.isEmpty
                  ? 0
                  : all.map((e) => e.position).reduce((a, b) => a > b ? a : b);
              position = maxPos + 1;
            }
            final lq = LanguageQuestion.fromQuestion(
              q,
              languageTypeId: languageId,
              themeId: themeId,
              position: position,
            );
            if (online) {
              if (q.id.isEmpty) {
                await service.addQuestion(lq);
              } else {
                await service.updateQuestion(lq);
              }
            } else {
              await PendingOperationService().enqueue(
                'language_questions',
                q.id.isEmpty ? 'insert' : 'update',
                lq.toSupabase()..remove('id'),
              );
            }
            return true;
          },
          deleteQuestion: (id) async {
            final online = await ConnectivityHelper.isOnline();
            if (online) {
              await service.deleteQuestion(id);
            } else {
              await PendingOperationService().enqueue(
                'language_questions',
                'delete',
                {'id': id},
              );
            }
            return true;
          },
        );
      },
    );
  }
}
