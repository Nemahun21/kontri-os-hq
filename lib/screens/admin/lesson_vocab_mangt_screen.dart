import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/lesson_vocab_service.dart';

class LessonVocabularyManagementScreen extends StatefulWidget {
  final String contentType; // 'adventure' or 'language'
  final String? category; // Adventure only
  final String? themeId; // Language only
  final String title;

  const LessonVocabularyManagementScreen({
    super.key,
    required this.contentType,
    this.category,
    this.themeId,
    required this.title,
  });

  @override
  State<LessonVocabularyManagementScreen> createState() =>
      _LessonVocabularyManagementScreenState();
}

class _LessonVocabularyManagementScreenState
    extends State<LessonVocabularyManagementScreen> {
  final LessonVocabularyService _service = LessonVocabularyService();
  List<LessonVocabulary> _items = [];
  bool _isLoading = true;

  String _selectedDifficulty = 'easy';

  bool get _isAdventure => widget.contentType == 'adventure';
  bool get _isLanguage => widget.contentType == 'language';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getVocabulary(
        contentType: widget.contentType,
        category: _isAdventure ? widget.category : null,
        themeId: _isLanguage ? widget.themeId : null,
      );
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<LessonVocabulary> get _filteredItems {
    if (_isLanguage) return _items;
    return _items.where((i) => i.difficulty == _selectedDifficulty).toList();
  }

  void _addItem() => _showEditor();
  void _editItem(LessonVocabulary item) => _showEditor(item: item);

  Future<void> _deleteItem(LessonVocabulary item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item.term}"?'),
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
    if (confirm == true) {
      await _service.delete(item.id);
      _load();
    }
  }

  Future<void> _showEditor({LessonVocabulary? item}) async {
    final isEdit = item != null;
    final termController = TextEditingController(text: item?.term ?? '');
    final definitionController = TextEditingController(
      text: item?.definition ?? '',
    );
    final pronunciationController = TextEditingController(
      text: item?.pronunciation ?? '',
    );
    final exampleController = TextEditingController(text: item?.example ?? '');
    final emojiController = TextEditingController(text: item?.emoji ?? '');
    // final positionController =
    //     TextEditingController(text: (item?.position ?? 1).toString());
    final imageUrlController = TextEditingController(
      text: item?.imageUrl ?? '',
    );

    // Only for Adventure
    String difficulty = item?.difficulty ?? _selectedDifficulty;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Vocabulary' : 'Add Vocabulary'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Difficulty dropdown – ADVENTURE ONLY
                  if (_isAdventure) ...[
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('💡 Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('🔥 Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('🌊 Hard')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => difficulty = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: emojiController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji (optional)',
                      hintText: 'e.g., 👋',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termController,
                    decoration: InputDecoration(
                      labelText: _isLanguage ? 'Word' : 'Term',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: definitionController,
                    decoration: InputDecoration(
                      labelText: _isLanguage ? 'Translation' : 'Definition',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_isLanguage) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pronunciationController,
                      decoration: const InputDecoration(
                        labelText: 'Pronunciation (optional)',
                        hintText: 'e.g., koo-sheh',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: exampleController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Example / Context (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // const SizedBox(height: 12),
                  // TextField(
                  //   controller: positionController,
                  //   keyboardType: TextInputType.number,
                  //   decoration: const InputDecoration(
                  //     labelText: 'Position',
                  //     border: OutlineInputBorder(),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Safety: for language, themeId MUST exist
                if (_isLanguage && widget.themeId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Theme ID is missing. Cannot save.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                int position;
                if (isEdit && item != null) {
                  position = item.position;
                } else {
                  // Find the highest position in the current filtered list, add 1
                  final siblings = _items
                      .where(
                        (i) =>
                            (_isAdventure && i.difficulty == difficulty) ||
                            (_isLanguage),
                      )
                      .toList();

                  if (siblings.isEmpty) {
                    position = 1;
                  } else {
                    final maxPos = siblings
                        .map((i) => i.position)
                        .reduce((a, b) => a > b ? a : b);
                    position = maxPos + 1;
                  }
                }

                final vocab = LessonVocabulary(
                  id: item?.id ?? '',
                  contentType: widget.contentType,
                  // Adventure: category + difficulty, Language: themeId only
                  category: _isAdventure ? widget.category : null,
                  themeId: _isLanguage ? widget.themeId : null,
                  difficulty: _isAdventure ? difficulty : null,
                  term: termController.text.trim(),
                  definition: definitionController.text.trim(),
                  pronunciation: pronunciationController.text.trim().isEmpty
                      ? null
                      : pronunciationController.text.trim(),
                  example: exampleController.text.trim().isEmpty
                      ? null
                      : exampleController.text.trim(),
                  emoji: emojiController.text.trim().isEmpty
                      ? null
                      : emojiController.text.trim(),
                  imageUrl: imageUrlController.text.trim().isEmpty
                      ? null
                      : imageUrlController.text.trim(),
                  position: position,
                );

                if (isEdit) {
                  await _service.update(vocab);
                } else {
                  await _service.add(vocab);
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
            if (isEdit && item != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Position: ${item.position}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (result == true) _load();
  }

  // ---------------------- BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3498DB);

    return Scaffold(
      appBar: AppBar(
        title: Text('Lesson Cards: ${widget.title}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Difficulty tabs – ADVENTURE ONLY
                if (_isAdventure) _buildDifficultyTabs(),
                // Table
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : _buildTable(accent),
                ),
              ],
            ),
    );
  }

  Widget _buildDifficultyTabs() {
    final difficulties = [
      {'key': 'easy', 'label': '💡 Easy', 'color': Colors.green},
      {'key': 'medium', 'label': '🔥 Medium', 'color': Colors.orange},
      {'key': 'hard', 'label': '🌊 Hard', 'color': Colors.blue},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: difficulties.map((d) {
          final key = d['key'] as String;
          final label = d['label'] as String;
          final color = d['color'] as Color;
          final isSelected = _selectedDifficulty == key;
          final count = _items.where((i) => i.difficulty == key).length;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? color : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _isAdventure
                ? 'No $_selectedDifficulty lesson cards yet.'
                : 'No lesson cards yet.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first card.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(Color accent) {
    final items = _filteredItems;

    final List<String> headers;
    final List<int> flexValues;

    if (_isLanguage) {
      headers = [
        'Word',
        'Translation',
        'Pronunciation',
        'Example',
        'Pos',
        'Actions',
      ];
      flexValues = [3, 3, 2, 4, 1, 3];
    } else {
      headers = ['Term', 'Definition', 'Example', 'Pos', 'Actions'];
      flexValues = [3, 4, 4, 1, 3];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: accent.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.style, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isLanguage
                        ? 'Lesson Cards'
                        : '${_selectedDifficulty.toUpperCase()} Lesson Cards',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
                      child: Text(
                        headers[i],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            ...items.asMap().entries.map((entry) {
              return _buildDataRow(
                index: entry.key,
                item: entry.value,
                flexValues: flexValues,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow({
    required int index,
    required LessonVocabulary item,
    required List<int> flexValues,
  }) {
    final List<Widget> cells = [];

    cells.add(Text('${index + 1}', style: const TextStyle(fontSize: 12)));

    cells.add(
      Row(
        children: [
          if (item.emoji != null && item.emoji!.isNotEmpty) ...[
            Text(item.emoji!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              item.term,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    cells.add(
      Text(
        item.definition,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );

    if (_isLanguage) {
      cells.add(
        Text(
          item.pronunciation ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontStyle: item.pronunciation != null
                ? FontStyle.italic
                : FontStyle.normal,
            color: Colors.grey[700],
          ),
        ),
      );
    }

    cells.add(
      Text(
        item.example ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );

    cells.add(Text('${item.position}', style: const TextStyle(fontSize: 12)));

    cells.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _editItem(item),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              child: const Icon(Icons.edit, color: Colors.blue, size: 16),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _deleteItem(item),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              child: const Icon(Icons.delete, color: Colors.red, size: 16),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          final isActionColumn = i == cells.length - 1; 
          final child = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: cells[i],
          );

          if (isActionColumn) {
            return SizedBox(
              width: 72,
              child: child,
            ); 
          }

          return Expanded(
            flex: i < flexValues.length ? flexValues[i] : 1,
            child: child,
          );
        }),
      ),
    );
  }
}
