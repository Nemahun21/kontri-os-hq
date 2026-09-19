import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    setState(() => _isLoading = true);
    try {
      final themes = await _service.getThemesForLanguage(widget.languageId);
      setState(() {
        _themes = themes;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
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

    if (themeName != null && themeName.isNotEmpty) {
      setState(() => _isLoading = true);
      final newTheme = await _service.createTheme(themeName, widget.languageId);
      if (newTheme != null && mounted) {
        setState(() {
          _themes.add(newTheme);
          _isLoading = false;
        });
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
          'Are you sure you want to delete the theme "${theme.name}"? All questions under this theme will also be deleted.',
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
    ).then((_) => _loadThemes());
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Colors.purple;

    return Scaffold(
      appBar: AppBar(
        title: Text('Themes: ${widget.languageName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadThemes,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTheme,
            tooltip: 'Add theme',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _themes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No themes yet. Add one with the + button.'),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // ---- Header ----
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Theme Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, color: Colors.grey.shade400),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  ..._themes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final theme = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade400),
                          right: BorderSide(color: Colors.grey.shade400),
                          bottom: BorderSide(color: Colors.grey.shade400),
                        ),
                        color: index.isEven
                            ? Colors.white
                            : Colors.grey.shade50,
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
                              child: Text(
                                theme.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Container(width: 1, color: Colors.grey.shade400),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.school, color: Colors.purple),
      tooltip: 'Manage lesson cards',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonVocabularyManagementScreen(
              contentType: 'language',
              themeId: theme.id,
              title: '${widget.languageName} • ${theme.name}',
            ),
          ),
        );
      },
    ),
    IconButton(
      icon: const Icon(Icons.visibility, color: Colors.blue),
      onPressed: () => _onThemeTap(theme),
      tooltip: 'View questions',
    ),
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => _deleteTheme(theme),
      tooltip: 'Delete theme',
    ),
  ],
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
    );
  }
}
