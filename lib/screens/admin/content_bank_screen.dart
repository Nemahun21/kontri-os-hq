import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/services/daily_content_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:kohntri_os_hq/screens/admin/daily_content_management_screen.dart';

// =========================================================================
// MAIN SCREEN
// =========================================================================
class ContentBankScreen extends StatefulWidget {
  const ContentBankScreen({super.key});

  @override
  State<ContentBankScreen> createState() => _ContentBankScreenState();
}

class _ContentBankScreenState extends State<ContentBankScreen> {
  final QuestionService _questionService = QuestionService();
  final DailyContentService _dailyService = DailyContentService();
  final LanguageQuestionService _langService = LanguageQuestionService();

  bool _isLoading = true;

  List<Question> _adventure = [];
  List<Map<String, dynamic>> _proverbs = [];
  List<Map<String, dynamic>> _funFacts = [];
  List<Map<String, dynamic>> _challenges = [];
  Map<String, Map<String, List<LanguageQuestion>>> _languages = {};

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    try {
      final adventure = await _questionService.getAllQuestions();
      final proverbs = await _dailyService.getAll(ContentType.proverb);
      final funFacts = await _dailyService.getAll(ContentType.funFact);
      final challenges = await _dailyService.getAll(ContentType.challenge);

      final languages = await _langService.getLanguages();
      final themesMap = await _langService.getAllThemesMap();
      final allLangQuestions = await _langService.getAllLanguageQuestions();

      final Map<String, Map<String, List<LanguageQuestion>>> langGroups = {};
      final langMap = {for (var l in languages) l['id']: l['name']};

      for (var q in allLangQuestions) {
        final langName = langMap[q.languageTypeId] ?? 'Unknown Language';
        final themeName = themesMap[q.themeId] ?? 'Unknown Theme';
        langGroups.putIfAbsent(langName, () => {});
        langGroups[langName]!.putIfAbsent(themeName, () => []);
        langGroups[langName]![themeName]!.add(q);
      }

      if (!mounted) return;
      setState(() {
        _adventure = adventure;
        _proverbs = proverbs;
        _funFacts = funFacts;
        _challenges = challenges;
        _languages = langGroups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('Error loading content: $e');
    }
  }

  // ---------------------- DETAIL DIALOG ----------------------
  void _showItemDetail(dynamic raw, String title, String contentType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _buildDetailContent(raw),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openEditScreen(raw, contentType);
              _loadAllContent();
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditScreen(dynamic raw, String contentType) async {
    switch (contentType) {
      case 'adventure':
        if (raw is Question) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddEditQuestionScreen(question: raw)),
          );
        }
        break;
      case 'proverb':
      case 'funFact':
      case 'challenge':
        final type = _mapStringToContentType(contentType);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DailyContentManagementScreen(contentType: type)),
        );
        break;
      case 'language':
        if (raw is LanguageQuestion) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditQuestionScreen(
                languageQuestion: raw,
                initialLanguageId: raw.languageTypeId,
                initialThemeId: raw.themeId,
                isDailyChallenge: false,
                initialCategory: 'Languages',
              ),
            ),
          );
        }
        break;
    }
  }

  ContentType _mapStringToContentType(String type) {
    switch (type) {
      case 'proverb':
        return ContentType.proverb;
      case 'funFact':
        return ContentType.funFact;
      case 'challenge':
        return ContentType.challenge;
      default:
        return ContentType.proverb;
    }
  }

  List<Widget> _buildDetailContent(dynamic raw) {
    if (raw is Question) {
      return [
        _detailRow('Question', raw.question),
        _detailRow('Category', raw.category),
        _detailRow('Type', raw.type.displayName),
        _detailRow('Difficulty', raw.difficulty.name),
        _detailRow('Points', '${raw.points}'),
        _detailRow('Options', raw.options.join(', ')),
        _detailRow('Correct Answer',
            raw.options.isNotEmpty ? raw.options[raw.correctAnswerIndex] : '—'),
        if (raw.scenario != null && raw.scenario!.isNotEmpty)
          _detailRow('Scenario', raw.scenario!),
        if (raw.wrongConsequence != null && raw.wrongConsequence!.isNotEmpty)
          _detailRow('Wrong Consequence', raw.wrongConsequence!),
        if (raw.culturalContext != null && raw.culturalContext!.isNotEmpty)
          _detailRow('Cultural Context', raw.culturalContext!),
        _detailRow('Explanation', raw.explanation),
      ];
    } else if (raw is Map<String, dynamic>) {
      final List<Widget> widgets = [];
      for (var entry in raw.entries) {
        if (entry.key == 'options' && entry.value is List) {
          widgets.add(_detailRow('Options', (entry.value as List).join(', ')));
        } else if (entry.key == 'correct_answer_index') {
          final options = raw['options'] as List?;
          final index = entry.value as int?;
          if (options != null && index != null && index < options.length) {
            widgets.add(_detailRow('Correct Answer', options[index].toString()));
          } else {
            widgets.add(_detailRow('Correct Answer', index?.toString() ?? '—'));
          }
        } else if (entry.key == 'image_url' && entry.value != null) {
          widgets.add(_detailRow('Image', entry.value.toString()));
        } else {
          widgets.add(_detailRow(entry.key, entry.value?.toString() ?? '—'));
        }
      }
      return widgets;
    } else if (raw is LanguageQuestion) {
      return [
        _detailRow('Question', raw.question),
        _detailRow('Type', raw.type),
        _detailRow('Points', '${raw.points}'),
        _detailRow('Position', '${raw.position}'),
        _detailRow('Explanation', raw.explanation ?? '—'),
        if (raw.imageUrl != null) _detailRow('Image', raw.imageUrl!),
        if (raw.audioUrl != null) _detailRow('Audio', raw.audioUrl!),
      ];
    }
    return [const Text('Unknown content type')];
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF2C3E50))),
          ),
        ],
      ),
    );
  }

  // ---------------------- BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Bank'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllContent,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Adventure subcategories
                  _buildAdventureSection(),
                  const SizedBox(height: 16),

                  // Daily content previews
                  _buildDailyPreview(
                    title: 'Daily Proverbs',
                    icon: Icons.format_quote,
                    accentColor: Colors.green.shade700,
                    items: _proverbs,
                    contentType: 'proverb',
                    titleKey: 'text',
                    subtitleBuilder: (p) => 'Meaning: ${p['meaning'] ?? '—'}',
                  ),
                  const SizedBox(height: 16),
                  _buildDailyPreview(
                    title: 'Daily Fun Facts',
                    icon: Icons.lightbulb,
                    accentColor: Colors.purple.shade600,
                    items: _funFacts,
                    contentType: 'funFact',
                    titleKey: 'text',
                    subtitleBuilder: (f) => 'Category: ${f['category'] ?? '—'}',
                  ),
                  const SizedBox(height: 16),
                  _buildDailyPreview(
                    title: 'Daily Challenges',
                    icon: Icons.local_fire_department,
                    accentColor: Colors.orange.shade700,
                    items: _challenges,
                    contentType: 'challenge',
                    titleKey: 'question',
                    subtitleBuilder: (c) =>
                        '${(c['options'] as List?)?.length ?? 0} options | ${c['points'] ?? 0} pts',
                  ),
                  const SizedBox(height: 16),

                  // Languages
                  _buildLanguagesTable(),
                ],
              ),
            ),
    );
  }

  // ---------------------- ADVENTURE SUB-CATEGORIES ----------------------
  Widget _buildAdventureSection() {
    // Group by category
    final Map<String, List<Question>> grouped = {};
    for (var q in _adventure) {
      grouped.putIfAbsent(q.category, () => []);
      grouped[q.category]!.add(q);
    }

    final subcategories = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          title: 'Adventure',
          icon: Icons.quiz,
          accentColor: const Color(0xFF9B59B6),
          count: _adventure.length,
        ),
        const SizedBox(height: 8),
        ...subcategories.map((cat) {
          final items = grouped[cat]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPreviewCard(
              title: cat,
              icon: _getCategoryIcon(cat),
              accentColor: _getCategoryColor(cat),
              items: items.map((q) => {
                    'title': q.question,
                    'subtitle': '${q.type.displayName} • ${q.difficulty.name} • ${q.points} pts',
                    'raw': q,
                  }).toList(),
              contentType: 'adventure',
              onViewAll: () => _openFullAdventureTable(cat, items),
            ),
          );
        }),
      ],
    );
  }

  void _openFullAdventureTable(String category, List<Question> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullTableScreen(
          title: 'Adventure — $category',
          accentColor: _getCategoryColor(category),
          headers: const ['#', 'Question', 'Type', 'Diff', 'Pts', 'Actions'],
          flexValues: const [1, 5, 2, 1, 1, 2],
          rows: items.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            return _FullTableRow(
              index: i,
              flexValues: const [1, 5, 2, 1, 1, 2],
              onTap: () => _showItemDetail(q, q.question, 'adventure'),
              cells: [
                Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(q.type.displayName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(q.difficulty.name, style: const TextStyle(fontSize: 12)),
                Text('${q.points}', style: const TextStyle(fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openEditScreen(q, 'adventure'),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------- DAILY PREVIEW CARD ----------------------
  Widget _buildDailyPreview({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, dynamic>> items,
    required String contentType,
    required String titleKey,
    required String Function(Map<String, dynamic>) subtitleBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          title: title,
          icon: icon,
          accentColor: accentColor,
          count: items.length,
        ),
        const SizedBox(height: 8),
        _buildPreviewCard(
          title: title,
          icon: icon,
          accentColor: accentColor,
          items: items.map((item) => {
                'title': item[titleKey]?.toString() ?? 'Untitled',
                'subtitle': subtitleBuilder(item),
                'raw': item,
              }).toList(),
          contentType: contentType,
          onViewAll: () => _openFullDailyTable(
            title: title,
            accentColor: accentColor,
            items: items,
            contentType: contentType,
            titleKey: titleKey,
          ),
        ),
      ],
    );
  }

  void _openFullDailyTable({
    required String title,
    required Color accentColor,
    required List<Map<String, dynamic>> items,
    required String contentType,
    required String titleKey,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullTableScreen(
          title: title,
          accentColor: accentColor,
          headers: const [ 'Content', 'Details', 'Pos', 'Actions'],
          flexValues: const [5, 4, 1, 3],
          rows: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final text = item[titleKey]?.toString() ?? 'Untitled';
            return _FullTableRow(
              index: i,
              flexValues: const [5, 4, 1, 3],
              onTap: () => _showItemDetail(item, text, contentType),
              cells: [
                Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  contentType == 'challenge'
                      ? '${(item['options'] as List?)?.length ?? 0} options'
                      : (item['meaning'] ?? item['category'] ?? '—').toString(),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${item['position'] ?? 0}', style: const TextStyle(fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openEditScreen(item, contentType),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------- PREVIEW CARD (3 items) ----------------------
  Widget _buildPreviewCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, dynamic>> items,
    required String contentType,
    required VoidCallback onViewAll,
  }) {
    final preview = items.take(3).toList();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: accentColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Preview items
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No items.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            )
          else
            ...preview.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return InkWell(
                onTap: () => _showItemDetail(item['raw'], item['title'], contentType),
                child: Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? 'Untitled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }),
          // View All button
          if (items.length > 3)
            InkWell(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.05),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All (${items.length})',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: accentColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------- SECTION HEADER ----------------------
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color accentColor,
    required int count,
  }) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: accentColor,
          ),
        ),
        const Spacer(),
        Text(
          '$count items',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ---------------------- LANGUAGES TABLE ----------------------
  Widget _buildLanguagesTable() {
    final languageNames = _languages.keys.toList()..sort();

    final flex = [3, 1, 1, 2];
    final rows = <Widget>[];

    for (int i = 0; i < languageNames.length; i++) {
      final langName = languageNames[i];
      final themes = _languages[langName]!;
      final themeCount = themes.keys.length;
      final questionCount = themes.values.fold<int>(0, (sum, list) => sum + list.length);

      rows.add(_buildRow(
        index: i,
        flexValues: flex,
        cells: [
          Text(langName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$themeCount', style: const TextStyle(fontSize: 12)),
          Text('$questionCount', style: const TextStyle(fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.blue, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showLanguageThemes(langName, themes),
              ),
            ],
          ),
        ],
      ));
    }

    return _buildTableCard(
      title: 'Languages',
      icon: Icons.language,
      accentColor: const Color(0xFF2ECC71),
      count: _languages.length,
      headers: const ['Language', 'Themes', 'Questions', 'Actions'],
      flexValues: flex,
      rows: rows,
    );
  }

  Widget _buildTableCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required int count,
    required List<String> headers,
    required List<int> flexValues,
    required List<Widget> rows,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: accentColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: accentColor)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: List.generate(headers.length, (i) {
                return Expanded(
                  flex: flexValues[i],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(headers[i],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF2C3E50))),
                  ),
                );
              }),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No items.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  Widget _buildRow({
    required int index,
    required List<int> flexValues,
    required List<Widget> cells,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: List.generate(cells.length, (i) {
            return Expanded(
              flex: flexValues[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cells[i],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _showLanguageThemes(String langName, Map<String, List<LanguageQuestion>> themes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$langName — Themes'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView(
            children: themes.entries.map((entry) {
              final themeName = entry.key;
              final questions = entry.value;
              return ListTile(
                title: Text(themeName),
                subtitle: Text('${questions.length} questions'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  _showThemeQuestions(langName, themeName, questions);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showThemeQuestions(String langName, String themeName, List<LanguageQuestion> questions) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$langName — $themeName'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (_, i) {
              final q = questions[i];
              return ListTile(
                leading: Text('${i + 1}'),
                title: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Type: ${q.type} | Points: ${q.points}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showItemDetail(q, q.question, 'language');
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'History':
        return Icons.history;
      case 'Food':
        return Icons.restaurant;
      case 'Sports':
        return Icons.sports_soccer;
      case 'Places':
        return Icons.map;
      default:
        return Icons.quiz;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'History':
        return const Color(0xFF3498DB);
      case 'Food':
        return const Color(0xFFE74C3C);
      case 'Sports':
        return const Color(0xFFF39C12);
      case 'Places':
        return const Color(0xFF1ABC9C);
      default:
        return const Color(0xFF9B59B6);
    }
  }
}

// =========================================================================
// FULL TABLE SCREEN (for View All)
// =========================================================================
class _FullTableScreen extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<String> headers;
  final List<int> flexValues;
  final List<Widget> rows;

  const _FullTableScreen({
    required this.title,
    required this.accentColor,
    required this.headers,
    required this.flexValues,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: accentColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: List.generate(headers.length, (i) {
                    return Expanded(
                      flex: flexValues[i],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          headers[i],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: accentColor,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// FULL TABLE ROW (shared widget)
// =========================================================================
class _FullTableRow extends StatelessWidget {
  final int index;
  final List<int> flexValues;
  final List<Widget> cells;
  final VoidCallback? onTap;

  const _FullTableRow({
    required this.index,
    required this.flexValues,
    required this.cells,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: List.generate(cells.length, (i) {
            return Expanded(
              flex: flexValues[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cells[i],
              ),
            );
          }),
        ),
      ),
    );
  }
}