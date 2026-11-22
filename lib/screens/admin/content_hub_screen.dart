import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:kohntri_os_hq/screens/admin/daily_content_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_bank_screen.dart';
import 'widgets/quick_add_question_sheet.dart';
import '../languages_management_screen.dart';

import 'package:kohntri_os_hq/admin_theme.dart';
import 'package:kohntri_os_hq/screens/admin/report_detail_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ContentHubScreen extends StatefulWidget {
  final int initialTab;
  
  

  const ContentHubScreen({super.key, this.initialTab = 0});

  @override
  State<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends State<ContentHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFab = true;
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_handleTabChange);
    _showFab = _tabController.index == 0;
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() => _showFab = _tabController.index == 0);
  }

  Future<void> _openQuickAddQuestionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const QuickAddQuestionSheet(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Question added')));
    }
  }

  Future<void> _openFullEditor({String? category}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(
          initialCategory: category ?? _activeCategory ?? 'General',
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Question saved')));
    }
  }

  Future<void> _onFabPressed() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Add question',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick for simple MCQ · Full editor for all types & tools',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.bolt_rounded)),
                  title: const Text('Quick add'),
                  subtitle: const Text('Fast multiple-choice sheet'),
                  onTap: () => Navigator.pop(ctx, 'quick'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.edit_note_rounded),
                  ),
                  title: const Text('Full editor'),
                  subtitle: const Text(
                    'All types, levels, audio, CSV queue, preview…',
                  ),
                  onTap: () => Navigator.pop(ctx, 'full'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.category_outlined),
                  ),
                  title: const Text('Full editor + choose category'),
                  subtitle: const Text('Pick category first, then open editor'),
                  onTap: () => Navigator.pop(ctx, 'full_category'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'quick') {
      await _openQuickAddQuestionSheet();
      return;
    }

    if (choice == 'full') {
      await _openFullEditor(category: _activeCategory);
      return;
    }

    if (choice == 'full_category') {
      final category = await _pickCategory();
      if (category != null && mounted) {
        await _openFullEditor(category: category);
      }
    }
  }

  Future<String?> _pickCategory() async {
    // Adjust to match your real categories
    const categories = [
      'Daily Challenge',
      'Proverbs',
      'Interesting Facts',
      'History',
      'Food',
      'Places',
      'Sports',
      'Languages',
    ];

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Select category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              for (final c in categories)
                ListTile(
                  title: Text(c),
                  trailing: c == (_activeCategory ?? 'General')
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(ctx, c),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Hub'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Questions'),
            Tab(text: 'Languages'),
            Tab(text: 'Daily'),
            Tab(text: 'Reports'),
            Tab(text: 'Contributions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
       children: const [
  _QuestionsTab(),
  _LanguagesTab(),
  _DailyContentTab(),
  _ReportsTab(),
  _ContributionsTab(),
],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.extended(
              onPressed: _onFabPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
// Questions tab
// ─────────────────────────────────────────────

class _QuestionsTab extends StatelessWidget {
  const _QuestionsTab();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: const ContentBankScreen());
  }
}

// ─────────────────────────────────────────────
// Languages tab
// ─────────────────────────────────────────────

class _LanguagesTab extends StatelessWidget {
  const _LanguagesTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const LanguagesManagementScreen(),
    );
  }
}
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  static const double _splitBreakpoint = 900;

  List<Map<String, dynamic>> _reports = [];
  final Set<String> _selected = <String>{};
  bool _loading = true;
  bool _selectMode = false;
  String? _filter = 'new'; // null = all
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      var query = Supabase.instance.client.from('content_reports').select(
            'id, category, language, content_id, message, created_at, status, user_id, app_version, platform, reviewed_at, review_notes',
          );
      if (_filter != null) query = query.eq('status', _filter!);
      final response =
          await query.order('created_at', ascending: false).limit(100);

      if (!mounted) return;
      final next = List<Map<String, dynamic>>.from(response as List);

      // Keep the open report if it's still listed; otherwise move to the
      // report that now sits in its place.
      final prevIndex =
          _reports.indexWhere((r) => r['id'].toString() == _activeId);
      String? nextActive = _activeId;
      if (next.isEmpty) {
        nextActive = null;
      } else if (!next.any((r) => r['id'].toString() == _activeId)) {
        final i = prevIndex < 0
            ? 0
            : (prevIndex >= next.length ? next.length - 1 : prevIndex);
        nextActive = next[i]['id'].toString();
      }

      setState(() {
        _reports = next;
        _activeId = nextActive;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to load reports: $error');
    }
  }

  void _setFilter(String? value) {
    if (value == _filter) return;
    setState(() {
      _filter = value;
      _selected.clear();
      _selectMode = false;
      _activeId = null;
      _reports = [];
    });
    _loadReports();
  }

  Future<bool> _setStatus(
    Map<String, dynamic> report,
    String status,
    String note,
  ) async {
    try {
      await Supabase.instance.client
          .from('content_reports')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': note,
          })
          .eq('id', report['id']);
    } catch (error) {
      _snack('Update failed: $error');
      return false;
    }
    if (!mounted) return true;
    await _loadReports();
    _snack(status == 'fixed' ? 'Report resolved' : 'Report dismissed');
    return true;
  }

  Future<void> _bulkUpdateStatus(String status, {String note = ''}) async {
    if (_selected.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('content_reports')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': note.isNotEmpty ? note : '(bulk)',
          })
          .inFilter('id', _selected.toList());
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      await _loadReports();
    } catch (error) {
      _snack('Update failed: $error');
    }
  }

  Future<void> _showRejectDialog() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss reports'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _bulkUpdateStatus('rejected', note: controller.text.trim());
    }
  }

  Map<String, dynamic>? _activeReport() {
    for (final r in _reports) {
      if (r['id'].toString() == _activeId) return r;
    }
    return null;
  }

  void _onTapReport(Map<String, dynamic> item, bool split) {
    final id = item['id'].toString();
    if (_selectMode) {
      setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });
      return;
    }
    setState(() => _activeId = id);
    if (split) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          report: item,
          onSetStatus: (status, note) => _setStatus(item, status, note),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final split = constraints.maxWidth >= _splitBreakpoint;
          final listPane = _buildListPane(split);
          if (!split) return listPane;

          final current = _activeReport();
          return Row(
            children: [
              SizedBox(width: 400, child: listPane),
              VerticalDivider(width: 1, color: AdminColors.border),
              Expanded(
                child: current == null
                    ? _detailPlaceholder()
                    : ReportDetailView(
                        key: ValueKey(current['id']),
                        report: current,
                        onSetStatus: (status, note) =>
                            _setStatus(current, status, note),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailPlaceholder() {
    if (_loading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 40, color: AdminColors.border),
          const SizedBox(height: 10),
          Text(
            _reports.isEmpty ? 'Nothing to review' : 'Select a report to review',
            style: TextStyle(color: AdminColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildListPane(bool split) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        if (_selectMode) _buildBulkBar(),
        Divider(height: 1, color: AdminColors.border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReports,
            child: _buildList(split),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    const options = <MapEntry<String?, String>>[
      MapEntry<String?, String>('new', 'Pending'),
      MapEntry<String?, String>('fixed', 'Resolved'),
      MapEntry<String?, String>('rejected', 'Dismissed'),
      MapEntry<String?, String>(null, 'All'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(o.value),
                        selected: _filter == o.key,
                        showCheckmark: false,
                        onSelected: (_) => _setFilter(o.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _selectMode ? 'Done' : 'Select several',
            icon: Icon(_selectMode ? Icons.close : Icons.checklist_rounded),
            onPressed: () => setState(() {
              _selectMode = !_selectMode;
              if (!_selectMode) _selected.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBar() {
    final none = _selected.isEmpty;
    return Container(
      color: AdminColors.blue.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Text(
            '${_selected.length} selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: none ? null : () => _bulkUpdateStatus('fixed'),
            child: const Text('Resolve'),
          ),
          TextButton(
            onPressed: none ? null : _showRejectDialog,
            child: Text(
              'Dismiss',
              style: TextStyle(color: none ? null : AdminColors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyText() {
    switch (_filter) {
      case 'new':
        return 'No pending reports.';
      case 'fixed':
        return 'No resolved reports.';
      case 'rejected':
        return 'No dismissed reports.';
      default:
        return 'No reports yet.';
    }
  }

  Widget _buildList(bool split) {
    if (_loading && _reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 240,
            child: Center(
              child: Text(
                _emptyText(),
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AdminColors.border),
      itemBuilder: (context, index) {
        final item = _reports[index];
        final id = item['id'].toString();
        return ReportListTile(
          report: item,
          selected: split && !_selectMode && id == _activeId,
          selectMode: _selectMode,
          checked: _selected.contains(id),
          onTap: () => _onTapReport(item, split),
          onLongPress: () => setState(() {
            _selectMode = true;
            _selected.add(id);
          }),
        );
      },
    );
  }
}
// ─────────────────────────────────────────────
// Daily tab
// ─────────────────────────────────────────────

class _DailyContentTab extends StatelessWidget {
  const _DailyContentTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const DailyContentOverview(),
    );
  }
}

// ─────────────────────────────────────────────
// Contributions tab
// ─────────────────────────────────────────────

class _ContributionsTab extends StatefulWidget {
  const _ContributionsTab();

  @override
  State<_ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends State<_ContributionsTab> {
  List<Map<String, dynamic>> _submissions = [];
  final Set<int> _selected = <int>{};
  bool _loading = true;

  Future<void> _loadSubmissions() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('content_submissions')
          .select(
            'id, submission_type, area, title, content, contact_info, credited_name, created_at, status',
          )
          .eq('status', 'new')
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _submissions = List<Map<String, dynamic>>.from(response as List);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load contributions: $error')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _bulkUpdateStatus(String status, {String note = ''}) async {
    if (_selected.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('content_submissions')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': note.isNotEmpty ? note : '(bulk)',
          })
          .inFilter('id', _selected.toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      await _loadSubmissions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $error')));
    }
  }

  Future<void> _rejectWithNote() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject submission'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _bulkUpdateStatus('rejected', note: controller.text.trim());
    }
  }

  Future<void> _needsInfoWithNote() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Needs info'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message to contributor',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _bulkUpdateStatus('needs_info', note: controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selected.isEmpty
          ? null
          : AppBar(
              title: Text('${_selected.length} selected'),
              actions: [
                TextButton(
                  onPressed: () async {
                    final item = _submissions.firstWhere(
                      (entry) => _selected.contains(entry['id']),
                      orElse: () => <String, dynamic>{},
                    );
                    if (item.isEmpty) return;
                    final q = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (ctx) => QuickAddQuestionSheet(
                        initialQuestion:
                            (item['title'] ?? item['content'] ?? '').toString(),
                        initialCategory: 'History',
                        initialDifficulty: 'medium',
                        initialCorrectAnswer: 'A',
                      ),
                    );
                    if (q == true) {
                      await Supabase.instance.client
                          .from('content_submissions')
                          .update({
                            'status': 'accepted',
                            'review_notes': 'Promoted to question',
                            'reviewed_at': DateTime.now().toIso8601String(),
                          })
                          .eq('id', item['id']);
                      await _loadSubmissions();
                    }
                  },
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: _rejectWithNote,
                  child: const Text('Reject'),
                ),
                TextButton(
                  onPressed: _needsInfoWithNote,
                  child: const Text('Needs info'),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadSubmissions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
            ? const Center(child: Text('No contributions in the queue.'))
            : ListView.builder(
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  final item = _submissions[index];
                  final selected = _selected.contains(item['id'] as int);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(item['id'] as int);
                        } else {
                          _selected.remove(item['id'] as int);
                        }
                      });
                    },
                    title: Text((item['title'] ?? 'Untitled').toString()),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['content'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['submission_type'] ?? 'question'} • ${_formatAge(item['created_at'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatAge(dynamic value) {
    if (value == null) return 'just now';
    try {
      final date = DateTime.parse(value.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return 'just now';
    }
  }
}

// ─────────────────────────────────────────────
// Direct entry points (used by the admin dashboard)
// ─────────────────────────────────────────────

class DailyManagementScreen extends StatelessWidget {
  const DailyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daily')),
    body: const _DailyContentTab(),
  );
}

class ReportsManagementScreen extends StatelessWidget {
  const ReportsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: const _ReportsTab(),
  );
}

class ContributionsManagementScreen extends StatelessWidget {
  const ContributionsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contributions')),
    body: const _ContributionsTab(),
  );
}
