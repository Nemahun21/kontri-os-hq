import 'package:flutter/material.dart';

import '../../admin_format.dart';
import '../../admin_theme.dart';
import '../../models/admin_lookup.dart';
import '../../models/question.dart';
import '../../services/admin_lookup_service.dart';
import '../../widgets/admin_card.dart';
import 'add_edit_question.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.contentId,
    required this.kind,
  });

  final String contentId;
  final String kind;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  AdminContentDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await AdminLookupService.contentDetail(widget.contentId, widget.kind);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = detail == null ? 'Content could not be loaded.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load content';
      });
    }
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminText.caption),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(int index, String option, int correctIndex) {
    final isCorrect = index == correctIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect
            ? AdminColors.green.withValues(alpha: 0.12)
            : AdminColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect ? AdminColors.green : AdminColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCorrect ? AdminColors.green : AdminColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: isCorrect ? AdminColors.card : AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor() async {
    if (_detail == null) return;

    try {
      final question = Question.fromSupabase(Map<String, dynamic>.from(_detail!.question));
      if (!mounted) return;

      final route = MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(
          question: question,
          initialCategory: question.category.isEmpty ? 'General' : question.category,
          initialLanguageId: _detail!.question['language_type_id']?.toString(),
          initialThemeId: _detail!.question['theme_id']?.toString(),
        ),
      );

      await Navigator.push(context, route);
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open editor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        title: const Text('Content Detail'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AdminColors.textPrimary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (_detail?.question['question'] ?? 'Untitled question').toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AdminPill(
                                  text: (widget.kind == 'language' ? 'Language' : 'Adventure').toUpperCase(),
                                  color: widget.kind == 'language' ? AdminColors.blue : AdminColors.amber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_detail?.question['options'] is List) ...[
                              ...(((_detail!.question['options'] as List?) ?? const <dynamic>[])
                                  .asMap()
                                  .entries
                                  .map((entry) => _optionRow(
                                        entry.key,
                                        entry.value?.toString() ?? '',
                                        ((_detail!.question['correct_answer_index'] ?? 0) as num).toInt(),
                                      )))
                            ],
                            const SizedBox(height: 8),
                            if (_detail?.question['category'] != null)
                              AdminCardLabel(
                                _detail!.question['category'].toString(),
                                color: AdminColors.blue2,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _miniStat(
                              'Attempts',
                              (_detail?.attemptsStats['attempts'] ?? '0').toString(),
                              AdminColors.blue2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              'Pass Rate',
                              '${((_detail?.attemptsStats['pass_rate'] ?? 0) as num).toStringAsFixed(0)}%',
                              AdminColors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              'Users',
                              (_detail?.attemptsStats['users'] ?? '0').toString(),
                              AdminColors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_detail != null && _detail!.reports.isNotEmpty) ...[
                        AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminCardLabel('REPORTS (${_detail!.reports.length})', color: AdminColors.red),
                              const SizedBox(height: 12),
                              ..._detail!.reports.map((report) {
                                final reportMessage = (report['message'] ?? report['reason'] ?? 'Report').toString();
                                final userId = (report['user_id'] ?? report['userId'] ?? '').toString();
                                final status = (report['status'] ?? 'open').toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reportMessage,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'from ${userId.isEmpty ? 'unknown user' : shortId(userId)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AdminColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AdminPill(
                                        text: status.toUpperCase(),
                                        color: AdminColors.red,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_detail != null && _detail!.recentAttempts.isNotEmpty) ...[
                        AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AdminCardLabel('RECENT ATTEMPTS', color: AdminColors.blue2),
                              const SizedBox(height: 12),
                              ..._detail!.recentAttempts.map((attempt) {
                                final userId = (attempt['user_id'] ?? attempt['userId'] ?? '').toString();
                                final correct = attempt['is_correct'] == true || attempt['correct'] == true;
                                final dateValue = attempt['created_at'] ?? attempt['createdAt'];
                                final date = dateValue is String ? DateTime.tryParse(dateValue) : null;
                                return Row(
                                  children: [
                                    Icon(
                                      correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: correct ? AdminColors.green : AdminColors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'User ${userId.isEmpty ? 'unknown' : shortId(userId)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AdminColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      date == null ? '' : relTime(date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AdminColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit question'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.blue,
                            foregroundColor: AdminColors.card,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
