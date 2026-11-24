import 'package:flutter/material.dart';
import '../services/lesson_vocab_service.dart';
import '../widgets/content_workspace_metrics.dart';
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
  List<Map<String,dynamic>>? _coverageRows;
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
      final coverageFuture = LessonVocabularyService().contentMetrics().then<List<Map<String,dynamic>>?>((v)=>v,onError:(Object e,StackTrace s)=>null);

      final languages = await languagesFuture;
      final counts = await countsFuture;
      final themeCounts = await themeCountsFuture;
      final coverage = await coverageFuture;

      languages.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      if (!mounted) return;
      setState(() {
        _coverageRows = coverage;
        _languages = languages;
        _languageCounts = counts;
        _themeCounts = themeCounts;
        _totalLangQuestions =
            counts.values.fold(0, (sum, count) => sum + count);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _coverageRows = null; });
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
    final rows = _coverageRows;
    final all = ContentCoverage.fromRows(rows ?? []);
    return Scaffold(
      appBar: AppBar(title:const Text('Languages'),actions:[
        IconButton(onPressed:_isLoading?null:_loadData,icon:const Icon(Icons.refresh),tooltip:'Refresh'),
      ]),
      floatingActionButton:FloatingActionButton.extended(onPressed:_isLoading?null:_addLanguage,
        icon:const Icon(Icons.add),label:const Text('Add language')),
      body:_isLoading?const Center(child:CircularProgressIndicator()):RefreshIndicator(
        onRefresh:_loadData,
        child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,100),children:[
          WorkspaceMetrics(values:{
            'Languages':'${_languages.length}', 'Themes':'${rows==null?_themeCounts.values.fold(0,(a,b)=>a+b):all.themes}',
            'Questions':'${rows==null?_totalLangQuestions:all.questions}', 'Vocabulary':rows==null?'—':'${all.vocabulary}',
            'Missing media':rows==null?'—':'${all.missing}',
          }),
          if(rows==null) const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Live media metrics unavailable. Refresh when online.')),
          const SizedBox(height:16),
          TextField(controller:_searchController,onChanged:(v)=>setState(()=>_searchQuery=v.trim()),
            decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search languages…',
              border:const OutlineInputBorder(),suffixIcon:IconButton(icon:const Icon(Icons.clear),onPressed:(){
                _searchController.clear();setState(()=>_searchQuery='');
              }))),
          const SizedBox(height:12),
          if(filtered.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No matching languages.'))),
          for(final lang in filtered) _languageCard(context,lang,rows),
        ]),
      ),
    );
  }

  Widget _languageCard(BuildContext context,Map<String,dynamic> lang,List<Map<String,dynamic>>? rows) {
    final id=lang['id'] as String,name=lang['name'] as String;
    final pending=id.startsWith('pending_');
    final stats=ContentCoverage.fromRows((rows??[]).where((r)=>r['language_id']==id));
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      ListTile(contentPadding:EdgeInsets.zero,
        leading:CircleAvatar(child:Text(name.isEmpty?'?':name[0].toUpperCase())),
        title:Text(name,style:const TextStyle(fontWeight:FontWeight.w700)),
        subtitle:Text('${rows==null?_themeCounts[id]??0:stats.themes} themes · ${rows==null?_languageCounts[name]??0:stats.questions} questions'
          '${rows==null||pending?"":" · ${stats.vocabulary} words"}${pending?" · Pending sync":""}'),
        onTap:pending?null:()=>_openThemes(id,name),
        trailing:pending?const Icon(Icons.sync):Row(mainAxisSize:MainAxisSize.min,children:[
          TextButton.icon(onPressed:()=>_openThemes(id,name),icon:const Icon(Icons.chevron_right),label:const Text('Themes')),
          PopupMenuButton<String>(tooltip:'Language actions',onSelected:(v){if(v=='delete')_deleteLanguage(lang);},
            itemBuilder:(_)=>const [PopupMenuItem(value:'delete',child:Text('Delete language…'))]),
        ])),
      if(rows!=null&&!pending) CoverageLines(coverage:stats),
    ])));
  }
}
