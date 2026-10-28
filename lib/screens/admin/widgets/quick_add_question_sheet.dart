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
  final _questionCtrl = TextEditingController();
  final _options = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  String _category = 'History';
  String _difficulty = 'medium';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      _questionCtrl.text = widget.initialQuestion!;
    }
    if (widget.initialCategory != null) _category = widget.initialCategory!;
    if (widget.initialDifficulty != null) _difficulty = widget.initialDifficulty!;
    if (widget.initialCorrectAnswer != null) {
      final idx = 'ABCD'.indexOf(widget.initialCorrectAnswer!.toUpperCase());
      _correctIndex = idx < 0 ? 0 : idx;
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final q = _questionCtrl.text.trim();
    final opts = _options.map((c) => c.text.trim()).toList();
    if (q.isEmpty || opts.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill question + all 4 options')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('questions').insert({
        'question': q,
        'options': opts,
        'correct_answer_index': _correctIndex,
        'category': _category,
        'difficulty': _difficulty,
        'points': 10,
        'type': 'multipleChoice',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add question',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _questionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 4; i++) ...[
                Row(
                  children: [
                    Radio<int>(
                      value: i,
                      groupValue: _correctIndex,
                      onChanged: (v) => setState(() => _correctIndex = v!),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _options[i],
                        decoration: InputDecoration(
                          labelText: 'Option ${String.fromCharCode(65 + i)}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'History', child: Text('History')),
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                        DropdownMenuItem(value: 'Places', child: Text('Places')),
                      ],
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save question'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}