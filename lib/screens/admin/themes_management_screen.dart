import 'package:flutter/material.dart';
import '../../services/lesson_vocab_service.dart';
import '../../widgets/content_workspace_metrics.dart';
import 'package:kohntri_os_hq/models/language_theme.dart';
import 'package:kohntri_os_hq/screens/admin/lesson_vocab_mangt_screen.dart';
import 'package:kohntri_os_hq/screens/admin/theme_questions_screen.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';

class ThemesManagementScreen extends StatefulWidget {
  final String languageId;
  final String languageName;

  const ThemesManagementScreen({
    super.key,
    required this.languageId,
    required this.languageName,
  });

  @override
  State<ThemesManagementScreen> createState() => _ThemesManagementScreenState();
}

class _ThemesManagementScreenState extends State<ThemesManagementScreen> {
  final LanguageQuestionService _service = LanguageQuestionService();
  List<LanguageTheme> _themes = [];
  bool _isLoading = true;
  String _query = '';
  List<Map<String,dynamic>>? _coverageRows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    if (!mounted) return;
    setState(() { _isLoading=true; _error=null; });
    try {
      final metrics = LessonVocabularyService().contentMetrics().then<List<Map<String,dynamic>>?>((v)=>v,onError:(Object e,StackTrace s)=>null);
      final themes=await _service.getThemesForLanguage(widget.languageId);
      final rows=await metrics;
      if (mounted) setState(() { _themes=themes; _coverageRows=rows; _isLoading=false; });
    } catch(e) {
      if(mounted) setState(() { _error=e.toString(); _coverageRows=null; _isLoading=false; });
    }
  }

  Future<void> _addTheme() async {
    final TextEditingController controller = TextEditingController();
    final themeName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Theme'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Theme Name',
            hintText: 'e.g., Greetings, Family, Numbers',
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted) return;
    if (themeName != null && themeName.isNotEmpty) {
      setState(() => _isLoading = true);
      final newTheme = await _service.createTheme(themeName, widget.languageId);
      if (newTheme != null && mounted) {
        await _loadThemes();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add theme'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTheme(LanguageTheme theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Theme'),
        content: Text(
          'Are you sure you want to delete the theme "${theme.name}"? Associated questions and lesson vocabulary may also be deleted. Stored media will not be automatically deleted.',
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
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final success = await _service.deleteTheme(theme.id);
    if (success && mounted) {
      await _loadThemes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete theme'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _onThemeTap(LanguageTheme theme) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemeQuestionsScreen(
          themeId: theme.id,
          themeName: theme.name,
          languageName: widget.languageName,
          languageId: widget.languageId,
        ),
      ),
    ).then((_) { if(mounted) _loadThemes(); });
  }

  Future<void> _openVocabulary(LanguageTheme theme) async {
    await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>LessonVocabularyManagementScreen(
      contentType:'language',themeId:theme.id,title:'${widget.languageName} • ${theme.name}')));
    if(mounted) await _loadThemes();
  }

  @override
  Widget build(BuildContext context) {
    final rows=_coverageRows;
    final stats=ContentCoverage.fromRows((rows??[]).where((r)=>r['language_id']==widget.languageId));
    final filtered=_themes.where((t)=>t.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      appBar:AppBar(title:Text('Themes: ${widget.languageName}'),actions:[
        IconButton(onPressed:_isLoading?null:_loadThemes,icon:const Icon(Icons.refresh),tooltip:'Refresh'),
        IconButton(onPressed:_isLoading?null:_addTheme,icon:const Icon(Icons.add),tooltip:'Add theme'),
      ]),
      body:_isLoading?const Center(child:CircularProgressIndicator()):RefreshIndicator(
        onRefresh:_loadThemes,child:ListView(padding:const EdgeInsets.all(16),children:[
          WorkspaceMetrics(values:{
            'Themes':'${_themes.length}','Vocabulary':rows==null?'—':'${stats.vocabulary}',
            'Questions':rows==null?'—':'${stats.questions}','Missing media':rows==null?'—':'${stats.missing}',
          }),
          if(_error!=null) Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          if(rows==null) const Text('Live content metrics unavailable. Refresh to retry.'),
          const SizedBox(height:16),
          TextField(onChanged:(v)=>setState(()=>_query=v.trim()),decoration:const InputDecoration(
            prefixIcon:Icon(Icons.search),hintText:'Search themes…',border:OutlineInputBorder())),
          const SizedBox(height:12),
          if(filtered.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No matching themes.'))),
          for(final theme in filtered) _themeCard(context,theme,rows),
        ])),
    );
  }

  Widget _themeCard(BuildContext context,LanguageTheme theme,List<Map<String,dynamic>>? rows) {
    final s=ContentCoverage.fromRows((rows??[]).where((r)=>r['theme_id']==theme.id));
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(12),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.folder_outlined)),
          title:Text(theme.name,style:const TextStyle(fontWeight:FontWeight.w700)),
          subtitle:Text(rows==null?'Metrics unavailable':'${s.vocabulary} words · ${s.questions} questions · ${s.missing} missing media'),
          trailing:PopupMenuButton<String>(tooltip:'Theme actions',onSelected:(v){if(v=='delete')_deleteTheme(theme);},
            itemBuilder:(_)=>const [PopupMenuItem(value:'delete',child:Text('Delete theme…'))])),
        if(rows!=null) CoverageLines(coverage:s),
        const SizedBox(height:10),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton.tonalIcon(onPressed:()=>_openVocabulary(theme),icon:const Icon(Icons.style_outlined),label:const Text('Vocabulary')),
          OutlinedButton.icon(onPressed:()=>_onThemeTap(theme),icon:const Icon(Icons.quiz_outlined),label:const Text('Questions')),
        ]),
      ])));
  }
}
