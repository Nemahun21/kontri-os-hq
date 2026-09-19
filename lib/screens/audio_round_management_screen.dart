import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/admin/add_edit_question.dart';
import 'package:kohntri_os_hq/services/question_service.dart';

class AudioRoundManagementScreen extends StatefulWidget {
  const AudioRoundManagementScreen({super.key});

  @override
  State<AudioRoundManagementScreen> createState() => _AudioRoundManagementScreenState();
}

class _AudioRoundManagementScreenState extends State<AudioRoundManagementScreen> {
  final QuestionService _questionService = QuestionService();
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _questionService.getQuestionsByCategory('Audio Round');
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Audio Round questions: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addQuestion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(initialCategory: 'Audio Round'),
      ),
    ).then((_) => _loadQuestions());
  }

  void _editQuestion(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(question: question,),
      ),
    ).then((_) => _loadQuestions());
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
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
    try {
      final success = await _questionService.deleteQuestion(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted'), backgroundColor: Colors.green),
        );
        _loadQuestions();
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Round'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addQuestion,
            tooltip: 'Add new question',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats card (use purple for Audio Round)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Questions:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_questions.length}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Question list
                Expanded(
                  child: _questions.isEmpty
                      ? const Center(child: Text('No audio round questions yet.'))
                      : ListView.builder(
                          itemCount: _questions.length,
                          itemBuilder: (ctx, index) {
                            final q = _questions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text('Points: ${q.points} • Type: ${q.type.displayName}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editQuestion(q),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteQuestion(q.id),
                                    ),
                                  ],
                                ),
                                onTap: () => _editQuestion(q),
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