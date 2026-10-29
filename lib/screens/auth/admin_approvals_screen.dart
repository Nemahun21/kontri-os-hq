import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('admins')
          .select(
            'id, email, name, description, role, status, created_at, requested_at',
          )
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _pending = List<Map<String, dynamic>>.from(rows as List);
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

  String _generateKey({int length = 24}) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    final key = _generateKey();
    final user = Supabase.instance.client.auth.currentUser;
    try {
      await Supabase.instance.client.from('admins').update({
        'status': 'active',
        'assigned_key': key,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': user?.id,
        'role': 'admin',
      }).eq('id', row['id']);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approved'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send this key to ${row['email']} securely (once):'),
              const SizedBox(height: 12),
              SelectableText(
                key,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                Navigator.pop(ctx);
              },
              child: const Text('Copy & close'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
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
    if (ok != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    try {
      await Supabase.instance.client.from('admins').update({
        'status': 'rejected',
        'review_notes': notes.text.trim(),
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': user?.id,
        'assigned_key': null,
      }).eq('id', row['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin requests'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _pending.isEmpty
                  ? const Center(child: Text('No pending requests'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pending.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = _pending[i];
                        return Card(
                          child: ListTile(
                            title: Text(row['name']?.toString() ?? '—'),
                            subtitle: Text(
                              '${row['email']}\n${row['description'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Approve',
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () => _approve(row),
                                ),
                                IconButton(
                                  tooltip: 'Reject',
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.red),
                                  onPressed: () => _reject(row),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}