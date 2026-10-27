import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuickAddQuestionSheet extends StatefulWidget {
  final String? initialQuestion;
  final String? initialCategory;
  final String? initialDifficulty;
  final String? initialCorrectAnswer;

  const QuickAddQuestionSheet({
    super.key,
    this.initialQuestion,
    this.initialCategory,
    this.initialDifficulty,
    this.initialCorrectAnswer,
  });

  @override
  State<QuickAddQuestionSheet> createState() => _QuickAddQuestionSheetState();
}

class _QuickAddQuestionSheetState extends State<QuickAddQuestionSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<String> _categories = ['History', 'Food', 'Sports', 'Places'];
  final List<String> _difficulties = ['easy', 'medium', 'hard'];
  final List<String> _answers = ['A', 'B', 'C', 'D'];

  String _selectedCategory = 'History';
  String _selectedDifficulty = 'easy';
  String _selectedAnswer = 'A';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionController.text = widget.initialQuestion ?? '';
    _selectedCategory = widget.initialCategory ?? 'History';
    _selectedDifficulty = widget.initialDifficulty ?? 'easy';
    _selectedAnswer = widget.initialCorrectAnswer ?? 'A';
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    final question = _questionController.text.trim();
    final options = _optionControllers.map((c) => c.text.trim()).toList();

    if (question.isEmpty || options.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final correctIndex = _answers.indexOf(_selectedAnswer);
      await Supabase.instance.client.from('questions').insert({
        'question': question,
        'options': options,
        'correct_answer_index': correctIndex,
        'category': _selectedCategory,
        'difficulty': _selectedDifficulty,
        'points': 10,
        'type': 'multipleChoice',
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add question: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add question',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _questionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(4, (index) {
                  final label = 'Option ${_answers[index]}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedCategory = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDifficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                        ),
                        items: _difficulties
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedDifficulty = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Correct answer',
                    border: OutlineInputBorder(),
                  ),
                  items: _answers
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedAnswer = value);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveQuestion,
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save question'),
                  ),
                ),
                const SizedBox(height: 12),
                Tooltip(
                  message: 'Coming soon',
                  child: IgnorePointer(
                    ignoring: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Bulk import (CSV)'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
