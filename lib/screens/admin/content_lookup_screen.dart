import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_theme.dart';
import '../../models/admin_lookup.dart';
import '../../services/admin_lookup_service.dart';
import '../../widgets/admin_card.dart';
import 'content_detail_screen.dart';

class ContentLookupScreen extends StatefulWidget {
  const ContentLookupScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<ContentLookupScreen> createState() => _ContentLookupScreenState();
}

class _ContentLookupScreenState extends State<ContentLookupScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  String _state = 'initial';
  List<AdminContentSummary> _results = const <AdminContentSummary>[];
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
        _results = const <AdminContentSummary>[];
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
      final results = await AdminLookupService.searchContent(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = results.isEmpty ? 'empty' : 'results';
        _error = results.isEmpty ? 'No content matches "$query"' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <AdminContentSummary>[];
        _state = 'empty';
        _error = 'Could not load content';
      });
    }
  }

  Widget _contentCard(AdminContentSummary content) {
    final isLanguage = content.kind == 'language';
    final color = isLanguage ? AdminColors.blue : AdminColors.amber;
    final kindLabel = isLanguage ? 'Language' : 'Adventure';

    return AdminCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContentDetailScreen(
            contentId: content.contentId,
            kind: isLanguage ? 'language' : 'adventure',
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              kindLabel,
              style: TextStyle(
                color: color,
                fontSize: 11,
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
                  content.question.isEmpty ? 'Untitled content' : content.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${content.category} · ${content.themeOrLevel}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${content.reportsCount} reports',
                style: TextStyle(
                  color: content.reportsCount > 0 ? AdminColors.red : AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(content.passRate * 100).round()}% pass',
                style: const TextStyle(
                  color: AdminColors.blue2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
        title: const Text('Content'),
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
                hintText: 'Search by question text, category, or content ID',
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
                    'Search content to inspect item health',
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                ),
              'loading' => const Center(child: CircularProgressIndicator()),
              'empty' => Center(
                  child: Text(
                    _error ?? 'No content found',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AdminColors.textSecondary),
                  ),
                ),
              _ => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _contentCard(_results[index]),
                ),
            },
          ),
        ],
      ),
    );
  }
}
