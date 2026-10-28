import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddQuestionModeSheet extends StatefulWidget {
  const AddQuestionModeSheet({super.key});

  @override
  State<AddQuestionModeSheet> createState() => _AddQuestionModeSheetState();
}

class _AddQuestionModeSheetState extends State<AddQuestionModeSheet> {
  static const List<String> _categories = ['History', 'Food', 'Sports', 'Places'];

  Future<void> _openAdventurePicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OptionSheet(
        title: 'Choose a category',
        options: _categories,
      ),
    );

    if (picked == null || !mounted) return;
    Navigator.pop(context, {'mode': 'adventure', 'category': picked});
  }

  Future<void> _openLanguagePicker() async {
    final sheetContext = context;
    List<Map<String, dynamic>> languages = const [];

    try {
      final response = await Supabase.instance.client
          .from('language_type')
          .select('id, name, color')
          .order('name');
      languages = List<Map<String, dynamic>>.from(response as List);
    } catch (error) {
      if (!sheetContext.mounted || !mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('Failed to load languages: $error')),
      );
      return;
    }

    if (!sheetContext.mounted || !mounted) return;

    if (languages.isEmpty) {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('No languages available yet.')),
      );
      return;
    }

    final selectedLanguage = await showModalBottomSheet<Map<String, dynamic>>(
      context: sheetContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePickerSheet(languages: languages),
    );

    if (selectedLanguage == null || !sheetContext.mounted || !mounted) return;

    final languageId = selectedLanguage['id'] as String?;
    final languageName = selectedLanguage['name'] as String?;

    if (languageId == null || languageName == null) {
      return;
    }

    List<Map<String, dynamic>> themes = const [];

    try {
      final response = await Supabase.instance.client
          .from('language_themes')
          .select('id, name, language_type_id, position')
          .eq('language_type_id', languageId)
          .order('position');
      themes = List<Map<String, dynamic>>.from(response as List);
    } catch (error) {
      if (!sheetContext.mounted || !mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('Failed to load themes: $error')),
      );
      return;
    }

    if (themes.isEmpty) {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('No themes yet for $languageName')),
      );
      return;
    }

    final selectedTheme = await showModalBottomSheet<Map<String, dynamic>>(
      context: sheetContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThemePickerSheet(themes: themes),
    );

    if (selectedTheme == null || !sheetContext.mounted || !mounted) return;

    final themeId = selectedTheme['id'] as String?;
    final themeName = selectedTheme['name'] as String?;

    if (themeId == null || themeName == null) {
      return;
    }

    Navigator.pop(context, {
      'mode': 'language',
      'languageId': languageId,
      'languageName': languageName,
      'themeId': themeId,
      'themeName': themeName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add question',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Adventure / Quiz'),
              subtitle: const Text('History, Food, Sports, Places'),
              onTap: _openAdventurePicker,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Daily Challenge'),
              subtitle: const Text("Today's rotation"),
              onTap: () => Navigator.pop(context, {'mode': 'daily'}),
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              subtitle: const Text('Krio, Mende, Temne...'),
              onTap: _openLanguagePicker,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet extends StatelessWidget {
  final String title;
  final List<String> options;

  const _OptionSheet({
    required this.title,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return ListTile(
                    title: Text(option),
                    onTap: () => Navigator.pop(context, option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> languages;

  const _LanguagePickerSheet({required this.languages});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select language',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  final name = (language['name'] ?? 'Language').toString();
                  final color = language['color'] as String?;

                  return ListTile(
                    leading: color != null && color.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Color(int.tryParse(color.replaceFirst('#', '0xFF')) ?? 0xFF9E9E9E),
                            radius: 12,
                          )
                        : const CircleAvatar(
                            radius: 12,
                            child: Icon(Icons.language, size: 14),
                          ),
                    title: Text(name),
                    onTap: () => Navigator.pop(context, language),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> themes;

  const _ThemePickerSheet({required this.themes});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select theme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  final name = (theme['name'] ?? 'Theme').toString();
                  return ListTile(
                    title: Text(name),
                    onTap: () => Navigator.pop(context, theme),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
