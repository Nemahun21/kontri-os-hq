import 'package:flutter/material.dart';

import '../../admin_theme.dart';
import '../../models/admin_lookup.dart';
import '../../models/question.dart';
import '../../services/admin_lookup_service.dart';
import 'add_edit_question.dart';

String _str(dynamic v) => v == null ? '' : v.toString().trim();

/// Stored values stay new / fixed / rejected. Only the labels change.
class ReportStatusInfo {
  const ReportStatusInfo(this.label, this.color);
  final String label;
  final Color color;

  factory ReportStatusInfo.of(String? raw) {
    switch (raw) {
      case 'new':
        return ReportStatusInfo('Pending', AdminColors.amber);
      case 'fixed':
        return ReportStatusInfo('Resolved', AdminColors.green);
      case 'rejected':
        return ReportStatusInfo('Dismissed', AdminColors.textSecondary);
      default:
        return ReportStatusInfo(
          (raw == null || raw.isEmpty) ? 'Unknown' : raw,
          AdminColors.textSecondary,
        );
    }
  }
}

String reportAge(dynamic value) {
  if (value == null) return 'just now';
  final date = DateTime.tryParse(value.toString());
  if (date == null) return 'just now';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

String reportDate(dynamic value) {
  final d = DateTime.tryParse(_str(value))?.toLocal();
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}

// ─────────────────────────────────────────────
// List row
// ─────────────────────────────────────────────

class ReportListTile extends StatelessWidget {
  const ReportListTile({
    super.key,
    required this.report,
    required this.selected,
    required this.selectMode,
    required this.checked,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, dynamic> report;
  final bool selected;
  final bool selectMode;
  final bool checked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final status = ReportStatusInfo.of(report['status']?.toString());
    final category =
        _str(report['category']).isEmpty ? 'General' : _str(report['category']);
    final language = _str(report['language']);
    final message = _str(report['message']);

    return Material(
      color: selected
          ? AdminColors.blue.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 1),
                  child: Icon(
                    checked
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: checked
                        ? AdminColors.blue
                        : AdminColors.textSecondary,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: category,
                                  style: TextStyle(
                                    color: AdminColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (language.isNotEmpty)
                                  TextSpan(
                                    text: ' · $language',
                                    style: TextStyle(
                                      color: AdminColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          reportAge(report['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.isEmpty ? 'No message provided' : message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: message.isEmpty
                            ? AdminColors.textSecondary
                            : AdminColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mobile wrapper
// ─────────────────────────────────────────────

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.onSetStatus,
  });

  final Map<String, dynamic> report;
  final Future<bool> Function(String status, String note) onSetStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        title: const Text('Report'),
      ),
      body: ReportDetailView(
        report: report,
        onSetStatus: (status, note) async {
          final ok = await onSetStatus(status, note);
          if (ok && context.mounted) Navigator.pop(context);
          return ok;
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Detail workspace
// ─────────────────────────────────────────────

enum _ContentState { loading, ready, unavailable, error }

class _Probe {
  const _Probe(this.detail, this.failed);
  final AdminContentDetail? detail;
  final bool failed;
}

class ReportDetailView extends StatefulWidget {
  const ReportDetailView({
    super.key,
    required this.report,
    required this.onSetStatus,
  });

  final Map<String, dynamic> report;

  /// Writes status + review note. Returns true on success.
  final Future<bool> Function(String status, String note) onSetStatus;

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  _ContentState _state = _ContentState.loading;
  AdminContentDetail? _detail;
  String _kind = '';
  String _unavailableReason = '';
  bool _busy = false;
  String _reporterName = '';
  String _reporterEmail = '';
  bool _reporterLoading = true;

  Future<void> _loadReporter() async {
    final uid = _str(widget.report['user_id']);
    if (uid.isEmpty) {
      _reporterLoading = false;
      return;
    }
    try {
      final d = await AdminLookupService.userDetail(uid);
      if (!mounted) return;
      setState(() {
        _reporterName = _str(d?.profile['display_name']);
        _reporterEmail = _str(d?.profile['email']);
        _reporterLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reporterLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadContent();
        _loadReporter();
  }

  Future<_Probe> _probe(String id, String kind) async {
    try {
      final d = await AdminLookupService.contentDetail(id, kind);
      if (d != null && d.question.isNotEmpty) {
        debugPrint('REPORT_QUESTION_ROW kind=$kind keys=${d.question.keys.toList()} row=${d.question}');
        return _Probe(d, false);
      }      return const _Probe(null, false);
    } catch (_) {
      return const _Probe(null, true);
    }
  }

  Future<void> _loadContent() async {
    final id = _str(widget.report['content_id']);
    if (id.isEmpty) {
      setState(() {
        _state = _ContentState.unavailable;
        _detail = null;
        _unavailableReason = 'This report has no linked content ID.';
      });
      return;
    }

    if (_state != _ContentState.loading) {
      setState(() => _state = _ContentState.loading);
    }

    final results = await Future.wait<_Probe>([
      _probe(id, 'language'),
      _probe(id, 'adventure'),
    ]);
    if (!mounted) return;

    final lang = results[0];
    final adv = results[1];

    setState(() {
      if (lang.failed || adv.failed) {
        _state = _ContentState.error;
        _detail = null;
      } else if (lang.detail != null && adv.detail != null) {
        _state = _ContentState.unavailable;
        _detail = null;
        _unavailableReason =
            'This ID matches records in both the language and adventure '
            'tables, so the source cannot be told apart.';
      } else if (lang.detail != null) {
        _state = _ContentState.ready;
        _detail = lang.detail;
        _kind = 'language';
      } else if (adv.detail != null) {
        _state = _ContentState.ready;
        _detail = adv.detail;
        _kind = 'adventure';
      } else {
        _state = _ContentState.unavailable;
        _detail = null;
        _unavailableReason =
            'No question with this ID was found in the language or adventure '
            'tables. It may have been deleted, or belong to a content type '
            'the lookup does not cover.';
      }
    });
  }

  // Same arguments ContentDetailScreen passes to the existing editor.
  Future<void> _openEditor() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      final question =
          Question.fromSupabase(Map<String, dynamic>.from(detail.question));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditQuestionScreen(
            question: question,
            initialCategory:
                question.category.isEmpty ? 'General' : question.category,
            initialLanguageId: detail.question['language_type_id']?.toString(),
            initialThemeId: detail.question['theme_id']?.toString(),
          ),
        ),
      );
      if (!mounted) return;
      _loadContent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open editor')),
      );
    }
  }

  Future<void> _close(String status) async {
    final resolve = status == 'fixed';
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: resolve ? 'Resolve report' : 'Dismiss report',
        hint: resolve ? 'What was fixed?' : 'Why is this report not valid?',
        confirmLabel: resolve ? 'Resolve' : 'Dismiss',
        confirmColor: resolve ? AdminColors.green : AdminColors.red,
      ),
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    await widget.onSetStatus(status, note);
    if (mounted) setState(() => _busy = false);
  }

  // ── build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final statusRaw = r['status']?.toString();
    final status = ReportStatusInfo.of(statusRaw);
    final isPending = statusRaw == 'new';
    final category =
        _str(r['category']).isEmpty ? 'General' : _str(r['category']);
    final bar = _actionBar(isPending);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(text: status.label, color: status.color, dot: true),
                        _Badge(text: category, color: AdminColors.blue2),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _contentSection(),
                    if (_state == _ContentState.ready) ...[
                      const SizedBox(height: 14),
                      _facts(_detail!.question),
                    ],
                    const SizedBox(height: 24),
                    _reporterSection(status, statusRaw),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (bar != null) bar,
      ],
    );
  }

  // ── reported content ───────────────────────

  Widget _contentSection() {
    Widget body;
    if (_state == _ContentState.loading) {
      body = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading reported content…',
            style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
          ),
        ],
      );
    } else if (_state == _ContentState.unavailable) {
      body = _notice(
        Icons.link_off_rounded,
        'Content unavailable',
        _unavailableReason,
      );
    } else if (_state == _ContentState.error) {
      body = _notice(
        Icons.error_outline_rounded,
        'Could not load content',
        'Check your connection and try again.',
        action: TextButton(onPressed: _loadContent, child: const Text('Retry')),
      );
    } else {
      body = _contentBody(_detail!.question);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('REPORTED CONTENT'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AdminColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.border),
          ),
          child: body,
        ),
      ],
    );
  }

  Widget _notice(IconData icon, String title, String body, {Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AdminColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AdminColors.textSecondary,
                ),
              ),
              if (action != null) action,
            ],
          ),
        ),
      ],
    );
  }

  List<String> _imageUrls(Map<String, dynamic> q) {
    final out = <String>[];
    final multi = q['image_urls'];
    if (multi is Map) {
      for (final v in multi.values) {
        final s = _str(v);
        if (s.isNotEmpty) out.add(s);
      }
    }
    final single = _str(q['image_url']);
    if (single.isNotEmpty && !out.contains(single)) out.add(single);
    return out.take(4).toList();
  }

  Widget _contentBody(Map<String, dynamic> q) {
    final scenario = _str(q['scenario']);
    final question = _str(q['question']);
    final explanation = _str(q['explanation']);
    final wrong = _str(q['wrong_consequence']);
    final cultural = _str(q['cultural_context']);
    final options = q['options'] is List
        ? (q['options'] as List).map((e) => e?.toString() ?? '').toList()
        : <String>[];
    final correct = (q['correct_answer_index'] as num?)?.toInt();
    final rawType = _str(q['type']);
    final type = rawType.isEmpty ? null : QuestionType.fromString(rawType);
    // Only these types use correct_answer_index as an option pointer.
    final marksCorrect = type == QuestionType.multipleChoice ||
        type == QuestionType.trueFalse ||
        type == QuestionType.imageChoice;
    final images = _imageUrls(q);

    final children = <Widget>[];

    if (scenario.isNotEmpty) {
      children.add(SelectableText(
        scenario,
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontStyle: FontStyle.italic,
          color: AdminColors.textSecondary,
        ),
      ));
      children.add(const SizedBox(height: 12));
    }

    children.add(SelectableText(
      question.isEmpty ? 'Untitled question' : question,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AdminColors.textPrimary,
      ),
    ));

    if (images.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images[i],
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: AdminColors.bg,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    if (options.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      for (var i = 0; i < options.length; i++) {
        children.add(_optionRow(i, options[i], marksCorrect && i == correct));
      }
    }

    void addNote(String label, String text) {
      if (text.isEmpty) return;
      children.add(const SizedBox(height: 16));
      children.add(_Label(label));
      children.add(const SizedBox(height: 4));
      children.add(SelectableText(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AdminColors.textPrimary,
        ),
      ));
    }

    addNote('EXPLANATION', explanation);
    addNote('WRONG-ANSWER CONSEQUENCE', wrong);
    addNote('CULTURAL CONTEXT', cultural);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _optionRow(int index, String option, bool isCorrect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isCorrect
            ? AdminColors.green.withValues(alpha: 0.10)
            : AdminColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              String.fromCharCode(65 + index),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isCorrect ? AdminColors.green : AdminColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              option,
              style: TextStyle(fontSize: 14, color: AdminColors.textPrimary),
            ),
          ),
          if (isCorrect)
            Icon(Icons.check_circle_rounded, size: 18, color: AdminColors.green),
        ],
      ),
    );
  }

  // ── metadata (only fields present on the loaded record) ──

  Widget _facts(Map<String, dynamic> q) {
    final facts = <MapEntry<String, String>>[];
    facts.add(MapEntry(
      'Source',
      _kind == 'language' ? 'Language question' : 'Adventure question',
    ));

       final levelNumber = int.tryParse(
      _str(_kind == 'language' ? q['position'] : q['level']),
    );
    facts.add(MapEntry('Level Number', levelNumber?.toString() ?? 'Not set'));

    final difficulty = _str(q['difficulty']);
    if (difficulty.isNotEmpty) facts.add(MapEntry('Difficulty', difficulty));

    final language = _str(q['language']);
    if (language.isNotEmpty) facts.add(MapEntry('Language', language));

    final rawType = _str(q['type']);
    if (rawType.isNotEmpty) {
      facts.add(MapEntry('Type', QuestionType.fromString(rawType).displayName));
    }

    final points = q['points'];
    if (points is num) facts.add(MapEntry('Points', points.toInt().toString()));

    final td = q['type_data'];
    final hasAudio = _str(q['audio_url']).isNotEmpty ||
        (td is Map && _str(td['audio_url']).isNotEmpty);
    if (hasAudio) facts.add(const MapEntry('Audio', 'Attached'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        spacing: 22,
        runSpacing: 6,
        children: [
          for (final f in facts)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${f.key}  ',
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                  TextSpan(
                    text: f.value,
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
        ],
      ),
    );
  }

  // ── reporter ───────────────────────────────

  Widget _reporterSection(ReportStatusInfo status, String? statusRaw) {
    final r = widget.report;
    final message = _str(r['message']);
    final bits = <String>[];
    final user = _str(r['user_id']);
    if (user.isNotEmpty) {
      bits.add('User ${user.length > 8 ? user.substring(0, 8) : user}');
    }
    final platform = _str(r['platform']);
    if (platform.isNotEmpty) bits.add(platform);
    final version = _str(r['app_version']);
    if (version.isNotEmpty) bits.add('v$version');
    final language = _str(r['language']);
    if (language.isNotEmpty) bits.add('Language: $language');

    final reviewNote = _str(r['review_notes']);
    final closed = statusRaw != 'new';
    final quiet = TextStyle(fontSize: 12, color: AdminColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label("REPORTER'S MESSAGE"),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminColors.border.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            message.isEmpty ? 'No message provided.' : message,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: message.isEmpty
                  ? AdminColors.textSecondary
                  : AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Submitted ${reportDate(r['created_at'])}', style: quiet),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Name: ${_reporterLoading ? 'Loading…' : (_reporterName.isEmpty ? 'Unavailable' : _reporterName)}'
            ' · Email: ${_reporterLoading ? 'Loading…' : (_reporterEmail.isEmpty ? 'Unavailable' : _reporterEmail)}',
            style: quiet,
          ),
        ),        if (bits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(bits.join(' · '), style: quiet),
          ),
        if (closed && (reviewNote.isNotEmpty || _str(r['reviewed_at']).isNotEmpty)) ...[
          const SizedBox(height: 18),
          _Label('${status.label.toUpperCase()} — REVIEW NOTE'),
          const SizedBox(height: 4),
          SelectableText(
            reviewNote.isEmpty ? '—' : reviewNote,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AdminColors.textPrimary,
            ),
          ),
          if (_str(r['reviewed_at']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('on ${reportDate(r['reviewed_at'])}', style: quiet),
            ),
        ],
      ],
    );
  }

  // ── actions ────────────────────────────────

  Widget? _actionBar(bool isPending) {
    final showEdit =
        _state == _ContentState.loading || _state == _ContentState.ready;
    if (!showEdit && !isPending) return null;

    final canEdit = _state == _ContentState.ready && !_busy;
    const pad = EdgeInsets.symmetric(vertical: 14, horizontal: 18);

    final Widget? edit = showEdit
        ? FilledButton.icon(
            onPressed: canEdit ? _openEditor : null,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Assess & Edit'),
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.blue,
              padding: pad,
            ),
          )
        : null;

    final secondary = <Widget>[];
    if (isPending) {
      secondary.add(
        showEdit
            ? OutlinedButton(
                onPressed: _busy ? null : () => _close('fixed'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.green,
                  side: BorderSide(
                    color: AdminColors.green.withValues(alpha: 0.5),
                  ),
                  padding: pad,
                ),
                child: const Text('Resolve'),
              )
            : FilledButton(
                onPressed: _busy ? null : () => _close('fixed'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.green,
                  padding: pad,
                ),
                child: const Text('Resolve'),
              ),
      );
      secondary.add(
        OutlinedButton(
          onPressed: _busy ? null : () => _close('rejected'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.red,
            side: BorderSide(color: AdminColors.red.withValues(alpha: 0.5)),
            padding: pad,
          ),
          child: const Text('Dismiss'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 520) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (edit != null) edit,
                      if (edit != null && secondary.isNotEmpty)
                        const SizedBox(height: 8),
                      if (secondary.isNotEmpty)
                        Row(
                          children: [
                            Expanded(child: secondary[0]),
                            const SizedBox(width: 8),
                            Expanded(child: secondary[1]),
                          ],
                        ),
                    ],
                  );
                }
                return Row(
                  children: [
                    if (edit != null) Expanded(child: edit) else const Spacer(),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      secondary[0],
                      const SizedBox(width: 8),
                      secondary[1],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small pieces
// ─────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AdminColors.textSecondary,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.dot = false});
  final String text;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final Color confirmColor;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = _ctrl.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Review note (required)',
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: note.isEmpty ? null : () => Navigator.pop(context, note),
          style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}