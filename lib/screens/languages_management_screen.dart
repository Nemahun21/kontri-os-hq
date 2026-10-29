import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/themes_management_screen.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LanguagesManagementScreen extends StatefulWidget {
  const LanguagesManagementScreen({super.key});

  @override
  State<LanguagesManagementScreen> createState() =>
      _LanguagesManagementScreenState();
}

class _LanguagesManagementScreenState extends State<LanguagesManagementScreen> {
  final LanguageQuestionService _langService = LanguageQuestionService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _languages = [];
  Map<String, int> _languageCounts = {};
  Map<String, int> _themeCounts = {};
  int _totalLangQuestions = 0;
  bool _isLoading = true;
  String _searchQuery = '';

  static const _accent = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _languages;
    final q = _searchQuery.toLowerCase();
    return _languages.where((lang) {
      final name = (lang['name'] as String? ?? '').toLowerCase();
      final code = (lang['code'] as String? ?? '').toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final languagesFuture = _langService.getLanguages();
      final countsFuture = _langService.getLanguageCounts();
      final themeCountsFuture = _langService.getThemeCountsByLanguage();

      final languages = await languagesFuture;
      final counts = await countsFuture;
      final themeCounts = await themeCountsFuture;

      languages.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      if (!mounted) return;
      setState(() {
        _languages = languages;
        _languageCounts = counts;
        _themeCounts = themeCounts;
        _totalLangQuestions =
            counts.values.fold(0, (sum, count) => sum + count);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('$e');
    }
  }

  Future<void> _addLanguage() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Language Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code (e.g. krio)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final code = codeController.text.trim();
              if (name.isEmpty || code.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Both fields are required.')),
                );
                return;
              }
              if (_languages.any((lang) => lang['name'] == name)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Language already exists.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _performAddLanguage(
        nameController.text.trim(),
        codeController.text.trim(),
      );
    }
  }

  Future<void> _performAddLanguage(String name, String code) async {
    try {
      final online = await ConnectivityHelper.isOnline();
      if (online) {
        await _langService.addLanguage(name, code);
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language "$name" added.')),
        );
      } else {
        await PendingOperationService().enqueue('language_type', 'insert', {
          'name': name,
          'code': code,
        });
        final newLang = {
          'id': 'pending_${DateTime.now().millisecondsSinceEpoch}',
          'name': name,
          'code': code,
        };
        setState(() {
          _languages.add(newLang);
          _languages.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
          _languageCounts[name] = 0;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline – will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteLanguage(Map<String, dynamic> lang) async {
    final id = lang['id'] as String;
    final name = lang['name'] as String;

    if (id.startsWith('pending_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete pending language. Wait for sync.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final count = _languageCounts[name] ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Language'),
        content: Text(
          count > 0
              ? 'Language "$name" has $count question(s). Deleting it will also delete all associated themes and questions. Are you sure?'
              : 'Delete language "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final online = await ConnectivityHelper.isOnline();
      if (online) {
        await _langService.deleteLanguage(id);
        final check = await Supabase.instance.client
            .from('language_type')
            .select('id')
            .eq('id', id)
            .maybeSingle();

        if (check != null) {
          throw Exception('Failed to delete language from database.');
        }

        await CacheService().set('languages_list', null);
        await CacheService().set('language_counts', null);
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language "$name" deleted.')),
        );
      } else {
        await PendingOperationService().enqueue('language_type', 'delete', {
          'id': id,
        });
        setState(() {
          _languages.removeWhere((l) => l['id'] == id);
          _languageCounts.remove(name);
          _totalLangQuestions =
              _languageCounts.values.fold(0, (sum, c) => sum + c);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleted offline – will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openThemes(String languageId, String languageName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemesManagementScreen(
          languageId: languageId,
          languageName: languageName,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLanguages;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Languages'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLanguage,
        backgroundColor: _accent,
        icon: const Icon(Icons.add),
        label: const Text('Add language'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade700, Colors.red.shade400],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Total language questions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '$_totalLangQuestions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search languages…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} language${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No languages match “$_searchQuery”.'
                                : 'No languages yet.\nTap “Add language” to create one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final lang = filtered[index];
                              final id = lang['id'] as String;
                              final name = lang['name'] as String;
                              final questionCount =
                                  _languageCounts[name] ?? 0;
                              final themeCount = _themeCounts[id] ?? 0;
                              final isPending = id.startsWith('pending_');

                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: isPending
                                      ? null
                                      : () => _openThemes(id, name),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              _accent.withOpacity(0.12),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: _accent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isPending) ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.sync,
                                                      size: 16,
                                                      color: Colors.orange,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$themeCount theme${themeCount == 1 ? '' : 's'}  ·  $questionCount question${questionCount == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isPending) ...[
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 22,
                                            ),
                                            tooltip: 'Delete',
                                            onPressed: () =>
                                                _deleteLanguage(lang),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}