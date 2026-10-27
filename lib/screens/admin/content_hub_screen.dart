import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_bank_screen.dart';
import 'widgets/quick_add_question_sheet.dart';
import '../languages_management_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added')),
      );
    }
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
          _ReportsTab(),
          _ContributionsTab(),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: _openQuickAddQuestionSheet,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  const _QuestionsTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const ContentBankScreen(),
    );
  }
}

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
  List<Map<String, dynamic>> _reports = [];
  final Set<int> _selected = <int>{};
  bool _loading = true;

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('content_reports')
          .select('id, category, language, content_id, message, created_at, status, user_id, app_version, platform')
          .eq('status', 'new')
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _reports = List<Map<String, dynamic>>.from(response as List);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $error')),
      );
    }
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
      });
      await _loadReports();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
    }
  }

  Future<void> _showRejectDialog() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject reports'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _bulkUpdateStatus('rejected', note: controller.text.trim());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
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
                  onPressed: () => _bulkUpdateStatus('fixed'),
                  child: const Text('Mark fixed'),
                ),
                TextButton(
                  onPressed: _showRejectDialog,
                  child: const Text('Reject'),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? const Center(child: Text('No reports in the queue.'))
                : ListView.builder(
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final item = _reports[index];
                      final selected = _selected.contains(item['id']);
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
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (item['category'] ?? 'General').toString(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (item['message'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${item['user_id'] ?? 'unknown'} • ${_formatAge(item['created_at'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: TextButton(
                          onPressed: () => _showReportDetails(item),
                          child: const Text('View'),
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

  Future<void> _showReportDetails(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report details'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${item['category'] ?? 'General'}'),
                const SizedBox(height: 8),
                Text('Language: ${item['language'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('Content ID: ${item['content_id'] ?? '-'}'),
                const SizedBox(height: 12),
                const Text('Message:'),
                const SizedBox(height: 6),
                Text((item['message'] ?? '').toString()),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Review note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark fixed'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == true) {
      await Supabase.instance.client
          .from('content_reports')
          .update({
            'status': 'fixed',
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': controller.text.trim().isEmpty ? '(bulk)' : controller.text.trim(),
          })
          .eq('id', item['id']);
      await _loadReports();
    } else if (result == false) {
      final note = controller.text.trim();
      await Supabase.instance.client
          .from('content_reports')
          .update({
            'status': 'rejected',
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': note.isEmpty ? 'Rejected' : note,
          })
          .eq('id', item['id']);
      await _loadReports();
    }
  }
}

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
          .select('id, submission_type, area, title, content, contact_info, credited_name, created_at, status')
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
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
          decoration: const InputDecoration(labelText: 'Review note', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
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
          decoration: const InputDecoration(labelText: 'Message to contributor', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => QuickAddQuestionSheet(
                        initialQuestion: (item['title'] ?? item['content'] ?? '').toString(),
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
                TextButton(onPressed: _rejectWithNote, child: const Text('Reject')),
                TextButton(onPressed: _needsInfoWithNote, child: const Text('Needs info')),
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
                      final selected = _selected.contains(item['id']);
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
                            Text((item['content'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
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
