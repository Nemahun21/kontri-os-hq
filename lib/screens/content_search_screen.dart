import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/category_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentSearchScreen extends StatefulWidget {
  const ContentSearchScreen({super.key});

  @override
  State<ContentSearchScreen> createState() => _ContentSearchScreenState();
}

class _ContentSearchScreenState extends State<ContentSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _duplicates = [];
  bool _searching = false;
  bool _loadingDuplicates = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _loadDuplicates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final rows = await Supabase.instance.client
          .from('questions')
          .select('id, question, type, points, category, difficulty')
          .ilike('question', '%$q%')
          .order('category')
          .order('question')
          .limit(100);
      if (!mounted) return;
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(rows as List);
        _searching = false;
      });
    } catch (e) {
      debugPrint('search failed: $e');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadDuplicates() async {
    setState(() => _loadingDuplicates = true);
    try {
      final rows =
          await Supabase.instance.client.rpc('find_duplicate_questions')
              as List;
      if (!mounted) return;
      setState(() {
        _duplicates = List<Map<String, dynamic>>.from(rows);
        _loadingDuplicates = false;
      });
    } catch (e) {
      debugPrint('duplicates failed: $e');
      if (mounted) setState(() => _loadingDuplicates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Search'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Duplicates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSearchTab(),
          _buildDuplicatesTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search across all categories…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        if (_searching)
          const LinearProgressIndicator()
        else
          const SizedBox(height: 4),
        Expanded(
          child: _searchCtrl.text.trim().isEmpty
              ? Center(
                  child: Text(
                    'Type a word to search all questions',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        'No matches',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : _buildResultList(_searchResults),
        ),
      ],
    );
  }

  Widget _buildResultList(List<Map<String, dynamic>> results) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final r = results[i];
        return Card(
  child: ListTile(
    onTap: () {
      final cat = (r['category'] ?? '').toString();
      if (cat.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailScreen(
            category: cat,
            initialDifficulty: (r['difficulty'] ?? '').toString(),
            initialQuestionId: (r['id'] ?? '').toString(),
          ),
        ),
      );
    },
    title: Text(
      (r['question'] ?? '').toString(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _chip((r['category'] ?? '').toString(), Colors.blue),
          _chip((r['type'] ?? '').toString(), Colors.purple),
          _chip('${r['points'] ?? 0} pts', Colors.amber),
        ],
      ),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
  ),
);
      },
    );
  }

  Widget _buildDuplicatesTab() {
    if (_loadingDuplicates) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_duplicates.isEmpty) {
      return Center(
        child: Text(
          'No duplicates found',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDuplicates,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _duplicates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final d = _duplicates[i];
          final count = (d['copies'] as num?)?.toInt() ?? 0;
          final text = (d['sample_question'] ?? '').toString();
          final categories = (d['categories'] as List?)?.cast<dynamic>() ?? [];
          final ids = (d['question_ids'] as List?)?.cast<dynamic>() ?? [];
          return Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: ListTile(
              title: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Appears $count× in: ${categories.join(", ")}',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
              trailing: Text(
                '${count}×',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              onTap: () => _showDuplicateDetail(ids, text),
            ),
          );
        },
      ),
    );
  }

  void _showDuplicateDetail(List<dynamic> ids, String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('${ids.length} copies found:'),
            const SizedBox(height: 8),
            ...ids.map((id) => ListTile(
                  dense: true,
                  title: Text(
                    'ID: $id',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}