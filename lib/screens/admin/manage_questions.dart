import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:kohntri_os_hq/services/question_service.dart';

class ManageQuestionsScreen extends StatefulWidget {
  const ManageQuestionsScreen({super.key});

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  final QuestionService _questionService = QuestionService();
  List<Question> _questions = [];
  List<Question> _filteredQuestions = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _searchController.addListener(_filterQuestions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      _questions = await _questionService.getAllQuestions();
      _filterQuestions();
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterQuestions() {
    var filtered = List<Question>.from(_questions);
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((q) => q.category == _selectedCategory).toList();
    }
    
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((q) => 
        q.question.toLowerCase().contains(query) ||
        q.category.toLowerCase().contains(query) ||
        (q.scenario?.toLowerCase().contains(query) ?? false) ||
        (q.wrongConsequence?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    setState(() => _filteredQuestions = filtered);
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _questionService.deleteQuestion(id);
      if (success && mounted) {
        await _loadQuestions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...{..._questions.map((q) => q.category)}];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Questions'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search questions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditQuestionScreen()),
          );
          if (result == true) _loadQuestions();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = cat;
                              _filterQuestions();
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: Colors.blue,
                          checkmarkColor: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Question list
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No questions found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredQuestions.length,
                          itemBuilder: (ctx, i) {
                            final q = _filteredQuestions[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text('${i + 1}'),
                                ),
                                title: Text(q.question, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Category & points row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(q.category, style: TextStyle(fontSize: 10, color: Colors.blue[700])),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text('${q.points}pts', style: TextStyle(fontSize: 10, color: Colors.amber[700])),
                                        ),
                                      ],
                                    ),
                                    // Scenario (if any)
                                    if (q.scenario != null && q.scenario!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '📖 Scenario: ${q.scenario}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    // Wrong consequence (if any)
                                    if (q.wrongConsequence != null && q.wrongConsequence!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '💀 Consequence: ${q.wrongConsequence}',
                                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    // Cultural context (if any)
                                    if (q.culturalContext != null && q.culturalContext!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '🌍 Context: ${q.culturalContext}',
                                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => AddEditQuestionScreen(question: q)),
                                        );
                                        if (result == true) _loadQuestions();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteQuestion(q.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}