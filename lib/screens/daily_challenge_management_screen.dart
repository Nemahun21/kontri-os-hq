import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/daily_challenge_question.dart';
import 'package:kohntri_os_hq/widgets/question_table.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';

class DailyChallengeManagementScreen extends StatelessWidget {
  const DailyChallengeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DailyChallengeService();
    return FutureBuilder<Set<String>>(
      future: PendingOperationService().getPendingIdsForTable(
        'daily_challenge_questions',
      ),
      builder: (context, snapshot) {
        final pendingIds = snapshot.data ?? {};
        return QuestionTable(
          title: 'Daily Challenge',
          accentColor: Colors.orange,
          cacheKey: 'daily_challenge',
          pendingIds: pendingIds,
          isDailyChallenge: true,

          columnLabels: const [
            'POS',
            'Difficulty',
            'Type',
            'Question',
            'Options',
            'Correct',
            'Explanation',
            'Scenario', // new
            'Consequence', // new
            'Cultural Context', // new
            'Points',
            'Actions',
          ],
          fetchQuestions: () async {
            final dailyQuestions = await service.getDailyChallengeQuestions();
            return dailyQuestions.map((dq) => dq.toQuestion()).toList();
          },
          saveQuestion: (q) async {
            final online = await ConnectivityHelper.isOnline();
            final all = await service.getDailyChallengeQuestions();
            int position;
            if (q.id.isNotEmpty) {
              final existing = all.firstWhere(
                (dq) => dq.id == q.id,
                orElse: () => all.first,
              );
              position = existing.position;
            } else {
              final used = all.map((e) => e.position).toSet();
              int nextPos = 1;
              while (used.contains(nextPos)) {
                nextPos++;
              }
              position = nextPos;
            }
            final dq = DailyChallengeQuestion.fromQuestion(
              q,
              dailyChallengeId: DailyChallengeService.activeDailyChallengeId,
              position: position,
            );
            if (online) {
              if (q.id.isEmpty) {
                await service.addQuestion(dq);
              } else {
                await service.updateQuestion(dq);
              }
            } else {
              await PendingOperationService().enqueue(
                'daily_challenge_questions',
                q.id.isEmpty ? 'insert' : 'update',
                dq.toSupabase()..remove('id'),
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
                'daily_challenge_questions',
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
