import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_format.dart';
import '../../admin_theme.dart';
import '../../models/admin_lookup.dart';
import '../../services/admin_lookup_service.dart';
import '../../widgets/admin_card.dart';
import 'user_detail_screen.dart';

class UserLookupScreen extends StatefulWidget {
  const UserLookupScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<UserLookupScreen> createState() => _UserLookupScreenState();
}

class _UserLookupScreenState extends State<UserLookupScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  String _state = 'initial';
  List<AdminUserSummary> _results = const <AdminUserSummary>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery ?? '';
    if (query.trim().isNotEmpty) {
      _controller.text = query;
      _search(query);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _state = 'initial';
        _results = const <AdminUserSummary>[];
        _error = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _state = 'loading';
      _error = null;
    });

    try {
      final results = await AdminLookupService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = results.isEmpty ? 'empty' : 'results';
        _error = results.isEmpty ? 'No users match "$query"' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <AdminUserSummary>[];
        _state = 'empty';
        _error = 'Could not load users';
      });
    }
  }

  Widget _userCard(AdminUserSummary user) {
    final label = (user.displayName ?? user.email).trim();
    final initial = label.isEmpty ? '?' : label[0].toUpperCase();

    return AdminCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserDetailScreen(userId: user.userId),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AdminColors.blue.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AdminColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.isEmpty ? user.email : label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.createdAt == null
                      ? 'Joined recently'
                      : 'Joined ${fmtDate(user.createdAt!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (user.isAdmin)
                const AdminPill(text: 'ADMIN', color: AdminColors.blue),
              if (user.isBanned)
                const AdminPill(text: 'BANNED', color: AdminColors.red),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        title: const Text('Users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery == null,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search by email, name, or user ID',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textSecondary),
                filled: true,
                fillColor: AdminColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminColors.blue2),
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (_state) {
              'initial' => const Center(
                  child: Text(
                    'Search users to view their activity',
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                ),
              'loading' => const Center(child: CircularProgressIndicator()),
              'empty' => Center(
                  child: Text(
                    _error ?? 'No users match',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AdminColors.textSecondary),
                  ),
                ),
              _ => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _userCard(_results[index]),
                ),
            },
          ),
        ],
      ),
    );
  }
}
