import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/themes_management_screen.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/widgets/compact_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LanguagesManagementScreen extends StatefulWidget {
  const LanguagesManagementScreen({super.key});

  @override
  State<LanguagesManagementScreen> createState() =>
      _LanguagesManagementScreenState();
}

class _LanguagesManagementScreenState extends State<LanguagesManagementScreen> {
  final LanguageQuestionService _langService = LanguageQuestionService();

  List<Map<String, dynamic>> _languages = []; // each: {'id', 'name'}
  Map<String, int> _languageCounts = {};
  Map<String, int> _themeCounts = {};
  int _totalLangQuestions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // Sort alphabetically by name
      languages.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      setState(() {
        _languages = languages;
        _languageCounts = counts;
        _themeCounts = themeCounts;
        _totalLangQuestions = counts.values.fold(
          0,
          (sum, count) => sum + count,
        );
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addLanguage() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Language Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Code (e.g., krio)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
              await _performAddLanguage(name, code);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAddLanguage(String name, String code) async {
    try {
      final online = await ConnectivityHelper.isOnline();
      if (online) {
        await _langService.addLanguage(name, code);
        await _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Language "$name" added.')));
      } else {
        await PendingOperationService().enqueue('language_type', 'insert', {
          'name': name,
          'code': code,
        });
        final newLang = {
          'id': 'pending_${DateTime.now().millisecondsSinceEpoch}',
          'name': name,
        };
        setState(() {
          _languages.add(newLang);
          _languages.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
          _languageCounts[name] = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language saved offline – will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error adding language: $e');
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
        title: const Text('Delete Language'),
        content: Text(
          count > 0
              ? 'Language "$name" has $count question(s). Deleting it will also delete all associated themes and questions. Are you sure?'
              : 'Are you sure you want to delete language "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final online = await ConnectivityHelper.isOnline();
      print('Deleting language ID: $id, online: $online'); // 👈 debug print

      if (online) {
        await _langService.deleteLanguage(id);

        // Verify deletion
        final check = await Supabase.instance.client
            .from('language_type')
            .select('id')
            .eq('id', id)
            .maybeSingle();

        if (check != null) {
          print(
            '⚠️ Language still exists after delete – cascade may have failed.',
          );
          throw Exception('Failed to delete language from database.');
        } else {
          print('✅ Language deleted from Supabase.');
        }

        // Clear caches and reload
        await CacheService().set('languages_list', null);
        await CacheService().set('language_counts', null);
        await _loadData();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Language "$name" deleted.')));
      } else {
        // Offline: enqueue and update UI
        await PendingOperationService().enqueue('language_type', 'delete', {
          'id': id,
        });
        setState(() {
          _languages.removeWhere((lang) => lang['id'] == id);
          _languageCounts.remove(name);
          _totalLangQuestions = _languageCounts.values.fold(
            0,
            (sum, count) => sum + count,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language deleted offline – will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error deleting language: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onLanguageTap(String languageId, String languageName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemesManagementScreen(
          languageId: languageId,
          languageName: languageName,
        ),
      ),
    );
    _loadData(); // refresh counts after returning
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Languages'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addLanguage,
            tooltip: 'Add language',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total questions card
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.red.shade700, Colors.red.shade400],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.language,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Total Language Questions:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$_totalLangQuestions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),

                  child: Text(
                    'Languages',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _languages.isEmpty
                      ? const Center(child: Text('No languages available.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              // ---- Header ----
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'Language',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      color: Colors.grey.shade400,
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Text(
                                          'Questions',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      color: Colors.grey.shade400,
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'Themes',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      color: Colors.grey.shade400,
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'Actions',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ---- Data rows ----
                              ..._languages.asMap().entries.map((entry) {
                                final index = entry.key;
                                final lang = entry.value;
                                final id = lang['id'] as String;
                                final name = lang['name'] as String;
                                final questionCount =
                                    _languageCounts[name] ?? 0;
                                final themeCount = _themeCounts[id] ?? 0;
                                final isPending = id.startsWith('pending_');
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                      right: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                      bottom: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    color: index.isEven
                                        ? Colors.white
                                        : Colors.grey.shade50, // zebra striping
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(name)),
                                              if (isPending)
                                                Icon(
                                                  Icons.sync,
                                                  size: 16,
                                                  color: Colors.orange,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        color: Colors.grey.shade400,
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            '$questionCount',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        color: Colors.grey.shade400,
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            '$themeCount',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        color: Colors.grey.shade400,
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          child: CompactActions(
                                            editIcon: Icons.arrow_forward,
                                            onEdit: isPending
                                                ? null
                                                : () =>
                                                      _onLanguageTap(id, name),
                                            onDelete: isPending
                                                ? null
                                                : () => _deleteLanguage(lang),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
