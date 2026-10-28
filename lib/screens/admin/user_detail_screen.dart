import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_format.dart';
import '../../admin_theme.dart';
import '../../models/admin_lookup.dart';
import '../../services/admin_lookup_service.dart';
import '../../widgets/admin_card.dart';
import 'content_detail_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  AdminUserDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await AdminLookupService.userDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = detail == null ? 'User could not be loaded.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load user details';
      });
    }
  }

  String _profileValue(String key, {String fallback = ''}) {
    final value = _detail?.profile[key];
    if (value == null) return fallback;
    return value.toString();
  }

  Future<void> _ban(String reason) async {
    if (_detail == null) return;
    final ok = await AdminLookupService.banUser(widget.userId, reason);
    if (!mounted) return;
    if (ok) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User banned')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ban failed')),
      );
    }
  }

  Future<void> _unban() async {
    final ok = await AdminLookupService.unbanUser(widget.userId);
    if (!mounted) return;
    if (ok) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unbanned')),
      );
    }
  }

  Future<void> _demote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demote user?'),
        content: const Text('This removes admin access from this account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Demote'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await AdminLookupService.demoteUser(widget.userId);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demotion failed')),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _profileValue('email');
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email available')),
      );
      return;
    }

    final ok = await AdminLookupService.sendPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset failed')),
      );
    }
  }

  Future<void> _showBanDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban this user'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Reason for ban',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) {
      return;
    }

    await _ban(reason);
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

  Widget _listPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(color: AdminColors.textSecondary)),
      ),
    );
  }

  Widget _activityList() {
    if (_detail == null || _detail!.recentAttempts.isEmpty) {
      return _listPlaceholder('No recent activity');
    }

    return ListView.separated(
      itemCount: _detail!.recentAttempts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _detail!.recentAttempts[index];
        final isCorrect = item['is_correct'] == true || item['correct'] == true;
        final themeId = (item['theme_id'] ?? item['themeId'] ?? item['content_id'] ?? item['contentId'] ?? '').toString();
        final contentId = (item['content_id'] ?? item['contentId'] ?? item['id'] ?? '').toString();
        final kind = themeId.startsWith('adventure_') ? 'adventure' : 'language';

        return ListTile(
          onTap: contentId.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentDetailScreen(contentId: contentId, kind: kind),
                    ),
                  ),
          leading: Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isCorrect ? AdminColors.green : AdminColors.red,
          ),
          title: Text(themeId.isEmpty ? 'Attempt' : themeId),
          subtitle: Text(
            item['status']?.toString() ?? (isCorrect ? 'Correct' : 'Incorrect'),
          ),
          trailing: Text(relTime(item['created_at'] is String ? DateTime.tryParse(item['created_at']) : null)),
        );
      },
    );
  }

  Widget _submissionsList() {
    if (_detail == null || _detail!.submissions.isEmpty) {
      return _listPlaceholder('No submissions');
    }

    return ListView.separated(
      itemCount: _detail!.submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _detail!.submissions[index];
        final status = (item['status'] ?? 'pending').toString();
        final dateValue = item['created_at'] ?? item['createdAt'];
        final date = dateValue is String ? DateTime.tryParse(dateValue) : null;

        return ListTile(
          title: Text((item['title'] ?? item['question'] ?? 'Submission').toString()),
          subtitle: Text(status),
          trailing: Text(date == null ? '' : fmtDate(date)),
        );
      },
    );
  }

  Widget _reportsList() {
    if (_detail == null || _detail!.reports.isEmpty) {
      return _listPlaceholder('No reports');
    }

    return ListView.separated(
      itemCount: _detail!.reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _detail!.reports[index];
        final contentId = (item['content_id'] ?? item['contentId'] ?? '').toString();
        final kind = (item['kind'] ?? '').toString();
        final dateValue = item['created_at'] ?? item['createdAt'];
        final date = dateValue is String ? DateTime.tryParse(dateValue) : null;

        return ListTile(
          onTap: contentId.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentDetailScreen(
                        contentId: contentId,
                        kind: kind.isEmpty || kind == 'language' ? 'language' : 'adventure',
                      ),
                    ),
                  ),
          title: Text((item['message'] ?? item['reason'] ?? 'Report').toString()),
          subtitle: Text('Category: ${item['category'] ?? 'general'}'),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (item['status'] ?? 'open').toString(),
                style: const TextStyle(color: AdminColors.red),
              ),
              const SizedBox(height: 4),
              Text(date == null ? '' : fmtDate(date)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _profileValue('display_name', fallback: _profileValue('name'));
    final email = _profileValue('email');
    final avatarLetter = (name.isEmpty ? email : name).trim();
    final letter = avatarLetter.isEmpty ? '?' : avatarLetter[0].toUpperCase();

    final isBanned = _detail?.profile['is_banned'] == true || _detail?.profile['isBanned'] == true;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        title: const Text('User Detail'),
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
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AdminColors.blue.withValues(alpha: 0.12),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  color: AdminColors.blue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? email : name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: AdminColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_detail?.isAdmin ?? false)
                                  const AdminPill(text: 'ADMIN', color: AdminColors.blue),
                                if (isBanned)
                                  const AdminPill(text: 'BANNED', color: AdminColors.red),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isBanned)
                            OutlinedButton.icon(
                              onPressed: _unban,
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Unban'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _showBanDialog,
                              icon: const Icon(Icons.block),
                              label: const Text('Ban'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _resetPassword,
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Reset password'),
                          ),
                          if (_detail?.isAdmin ?? false)
                            OutlinedButton.icon(
                              onPressed: _demote,
                              icon: const Icon(Icons.people_alt_outlined),
                              label: const Text('Demote'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _miniStat(
                              'Score',
                              (_profileValue('total_score', fallback: '0')).toString(),
                              AdminColors.blue2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              'Streak',
                              (_profileValue('current_streak', fallback: '0')).toString(),
                              AdminColors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              'Joined',
                              _profileValue('created_at').isEmpty
                                  ? '—'
                                  : fmtDate(DateTime.tryParse(_profileValue('created_at')) ?? DateTime.now()),
                              AdminColors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AdminColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AdminColors.blue,
                          unselectedLabelColor: AdminColors.textSecondary,
                          indicatorColor: AdminColors.blue,
                          tabs: const [
                            Tab(text: 'Activity'),
                            Tab(text: 'Submissions'),
                            Tab(text: 'Reports'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 420,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _activityList(),
                            _submissionsList(),
                            _reportsList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
