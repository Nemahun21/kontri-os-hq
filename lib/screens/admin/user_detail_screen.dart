import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/services/admin_lookup_service.dart';


class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await AdminLookupService.userDetail(widget.userId);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _error = 'User not found or access denied';
          _loading = false;
        });
        return;
      }
      setState(() {
        _profile = detail.profile;
        _isAdmin = detail.isAdmin;
        _activity = detail.recentAttempts;
        _submissions = detail.submissions;
        _reports = detail.reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ban() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban user'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await AdminLookupService.banUser(
        widget.userId, reasonCtrl.text.trim());
    if (!mounted) return;
    if (success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ban failed')),
      );
    }
  }

  Future<void> _unban() async {
    final success = await AdminLookupService.unbanUser(widget.userId);
    if (!mounted) return;
    if (success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unban failed')),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = (_profile?['email'] ?? '').toString();
    if (email.isEmpty) return;
    final ok = await AdminLookupService.sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Password reset email sent to $email' : 'Send failed',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _demote() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin access?'),
        content: const Text(
          'This user will lose access to HQ. Their auth account remains.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Demote',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    final success = await AdminLookupService.demoteUser(widget.userId);
    if (!mounted) return;
    if (success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demote failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final p = _profile!;
    final name = (p['display_name'] ?? p['email'] ?? 'User').toString();
    final email = (p['email'] ?? '').toString();
    final score = (p['total_score'] as num?)?.toInt() ?? 0;
    final streak = (p['current_streak'] as num?)?.toInt() ?? 0;
    final longest = (p['longest_streak'] as num?)?.toInt() ?? 0;
    final quests = (p['quests_taken'] as num?)?.toInt() ?? 0;
    final accuracy = (p['accuracy'] as num?)?.toDouble() ?? 0;
    final daily = (p['daily_challenges_completed'] as num?)?.toInt() ?? 0;
    final isBanned = p['is_banned'] == true;
    final isActive = p['is_active'] != false;
    final joined = p['created_at'] as String?;
    final lastActive = p['last_active_at'] as String?;
    final preferredLang = (p['preferred_language'] ?? 'en').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Activity (${_activity.length})'),
            Tab(text: 'Submissions (${_submissions.length})'),
            Tab(text: 'Reports (${_reports.length})'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildOverviewTab(
            name: name,
            email: email,
            score: score,
            streak: streak,
            longest: longest,
            quests: quests,
            accuracy: accuracy,
            daily: daily,
            isBanned: isBanned,
            isActive: isActive,
            joined: joined,
            lastActive: lastActive,
            preferredLang: preferredLang,
          ),
          _buildListTab(
            _submissions,
            (s) => ListTile(
              title: Text((s['title'] ?? 'Untitled').toString()),
              subtitle: Text(
                '${s['submission_type'] ?? '?'} • ${s['status'] ?? '?'}'
                '\n${_relTime(s['created_at'] as String?)}',
              ),
              isThreeLine: true,
            ),
            'No submissions',
          ),
          _buildListTab(
            _reports,
            (r) => ListTile(
              title: Text((r['message'] ?? '').toString(),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${r['category'] ?? '?'} • ${r['status'] ?? '?'}'
                '\n${_relTime(r['created_at'] as String?)}',
              ),
              isThreeLine: true,
            ),
            'No reports',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab({
    required String name,
    required String email,
    required int score,
    required int streak,
    required int longest,
    required int quests,
    required double accuracy,
    required int daily,
    required bool isBanned,
    required bool isActive,
    required String? joined,
    required String? lastActive,
    required String preferredLang,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isBanned
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isBanned
                                ? Colors.red.shade700
                                : Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text(email,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_isAdmin)
                        _pill('ADMIN', Colors.purple),
                      if (isBanned)
                        _pill('BANNED', Colors.red)
                      else if (!isActive)
                        _pill('INACTIVE', Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Score & stats grid
          Row(
            children: [
              Expanded(child: _statTile('Score', '$score', Colors.amber)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile(
                      'Streak', '$streak', Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Longest', '$longest', Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statTile('Quests', '$quests', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile(
                      'Accuracy', '${accuracy.toStringAsFixed(1)}%',
                      Colors.green)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile('Daily', '$daily', Colors.purple)),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _infoRow('Joined', _dateLabel(joined)),
          _infoRow('Last active', _relTime(lastActive)),
          _infoRow('Preferred language', preferredLang),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: isBanned
                    ? FilledButton.icon(
                        onPressed: _unban,
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Unban'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                      )
                    : OutlinedButton.icon(
                        onPressed: _ban,
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Ban'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetPassword,
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: const Text('Reset pw'),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _demote,
                    icon: const Icon(Icons.person_remove, size: 16),
                    label: const Text('Demote'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade400),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Recent activity preview (last 5)
          if (_activity.isNotEmpty) ...[
            Text('Recent activity',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            ..._activity.take(5).map((a) => _activityTile(a)),
            if (_activity.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${_activity.length - 5} more in Activity tab',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> a) {
    final correct = a['correct'] == true;
    return ListTile(
      dense: true,
      leading: Icon(
        correct ? Icons.check_circle : Icons.cancel,
        color: correct ? Colors.green : Colors.red,
        size: 18,
      ),
      title: Text(
        (a['theme_id'] ?? '').toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        _relTime(a['created_at'] as String?),
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildListTab(
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) builder,
    String emptyText,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: Colors.grey[600])),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) => Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: builder(items[i]),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color.shade800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color.shade700)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.shade800),
      ),
    );
  }

  String _relTime(String? iso) {
    if (iso == null) return 'never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String _dateLabel(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}