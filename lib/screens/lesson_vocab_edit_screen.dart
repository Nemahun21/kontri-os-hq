import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/lesson_vocab_service.dart';

class LessonVocabEditScreen extends StatefulWidget {
  final LessonVocabulary? existing;
  final String? initialCategory;
  final String? initialDifficulty;
  final String? initialThemeId;

  const LessonVocabEditScreen({
    super.key,
    this.existing,
    this.initialCategory,
    this.initialDifficulty,
    this.initialThemeId,
  });

  @override
  State<LessonVocabEditScreen> createState() => _LessonVocabEditScreenState();
}

class _LessonVocabEditScreenState extends State<LessonVocabEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LessonVocabularyService();

  late String _contentType;
  String? _category;
  String? _difficulty;
  String? _themeId;

  late TextEditingController _termCtrl;
  late TextEditingController _defCtrl;
  late TextEditingController _exampleCtrl;
  late TextEditingController _reviewCtrl;
  late TextEditingController _pronCtrl;
  late TextEditingController _emojiCtrl;
  late TextEditingController _audioCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _posCtrl;

  bool _saving = false;

  static const _adventureCategories = ['History', 'Food', 'Sports', 'Places'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    // If editing, use existing values. Otherwise seed from presets.
    if (e != null) {
      _contentType = e.contentType;
      _category = e.category;
      _difficulty = e.difficulty;
      _themeId = e.themeId;
    } else {
      // Presets from the caller (e.g., category detail screen) win.
      _contentType = widget.initialThemeId != null ? 'language' : 'adventure';
      _category = widget.initialCategory;
      _difficulty = widget.initialDifficulty ?? 'easy';
      _themeId = widget.initialThemeId;
    }

    _termCtrl = TextEditingController(text: e?.term ?? '');
    _defCtrl = TextEditingController(text: e?.definition ?? '');
    _exampleCtrl = TextEditingController(text: e?.example ?? '');
    _reviewCtrl = TextEditingController(text: e?.reviewNote ?? '');
    _pronCtrl = TextEditingController(text: e?.pronunciation ?? '');
    _emojiCtrl = TextEditingController(text: e?.emoji ?? '');
    _audioCtrl = TextEditingController(text: e?.audioUrl ?? '');
    _imageCtrl = TextEditingController(text: e?.imageUrl ?? '');
    _posCtrl = TextEditingController(text: (e?.position ?? 1).toString());
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    _defCtrl.dispose();
    _exampleCtrl.dispose();
    _reviewCtrl.dispose();
    _pronCtrl.dispose();
    _emojiCtrl.dispose();
    _audioCtrl.dispose();
    _imageCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentType != 'language') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Adventure is read-only in this preview.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_difficulty == null) return; // Never overwrite a language level with null.
    setState(() => _saving = true);

    try {
      final vocab = LessonVocabulary(
        id: widget.existing?.id ?? '',
        contentType: _contentType,
        category: _contentType == 'adventure' ? _category : null,
        themeId: _contentType == 'language' ? _themeId : null,
        difficulty: _difficulty,
        term: _termCtrl.text.trim(),
        definition: _defCtrl.text.trim(),
        pronunciation: _pronCtrl.text.trim().isEmpty
            ? null
            : _pronCtrl.text.trim(),
        example: _exampleCtrl.text.trim().isEmpty
            ? null
            : _exampleCtrl.text.trim(),
        reviewNote: _reviewCtrl.text.trim(),
        emoji: _emojiCtrl.text.trim().isEmpty ? null : _emojiCtrl.text.trim(),
        audioUrl: _audioCtrl.text.trim().isEmpty
            ? null
            : _audioCtrl.text.trim(),
        imageUrl: _imageCtrl.text.trim().isEmpty
            ? null
            : _imageCtrl.text.trim(),
        position: int.tryParse(_posCtrl.text.trim()) ?? 1,
        fileSlug: widget.existing?.fileSlug,
      );

      if (widget.existing == null) {
        await _service.add(vocab);
      } else {
        await _service.update(vocab);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final isAdventure = _contentType == 'adventure';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit lesson entry' : 'New lesson entry'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save draft'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Content type ─────────────────────────────
            DropdownButtonFormField<String>(
              value: _contentType,
              decoration: const InputDecoration(
                labelText: 'Content type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'adventure', child: Text('Adventure')),
                DropdownMenuItem(value: 'language', child: Text('Language')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _contentType = v;
                  if (v == 'language') {
                    _category = null;
                    _difficulty ??= 'easy';
                  } else {
                    _themeId = null;
                    _category ??= widget.initialCategory;
                    _difficulty ??= widget.initialDifficulty ?? 'easy';
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // ── Adventure: category + difficulty ─────────
            if (isAdventure) ...[
              DropdownButtonFormField<String>(
                value: _adventureCategories.contains(_category)
                    ? _category
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _adventureCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
            ],

            // Store identical DB values for Adventure and Language.
            DropdownButtonFormField<String>(
              value: const ['easy', 'medium', 'hard'].contains(_difficulty)
                  ? _difficulty
                  : null,
              decoration: const InputDecoration(
                labelText: 'Vocabulary difficulty',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Beginner / Easy')),
                DropdownMenuItem(value: 'medium', child: Text('Intermediate / Medium')),
                DropdownMenuItem(value: 'hard', child: Text('Advanced / Hard')),
              ],
              onChanged: (v) => setState(() => _difficulty = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Language: theme id ───────────────────────
            if (!isAdventure) ...[
              TextFormField(
                initialValue: _themeId,
                decoration: const InputDecoration(
                  labelText: 'Theme ID (UUID)',
                  helperText:
                      'Paste the theme UUID from Language Themes management.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _themeId = v,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
            ],

            // ── Term ─────────────────────────────────────
            TextFormField(
              controller: _termCtrl,
              decoration: const InputDecoration(
                labelText: 'Term',
                hintText: 'e.g., COCONUT CAKE',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Definition ───────────────────────────────
            TextFormField(
              controller: _defCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Definition',
                hintText: 'Short description shown to the learner',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            if (_contentType == 'language') ...[
              TextFormField(controller:_reviewCtrl,maxLines:3,
                decoration:const InputDecoration(labelText:'Editorial review note (HQ only)',
                  helperText:'Clear after native-speaker validation.',border:OutlineInputBorder())),
              const SizedBox(height:12),
            ],
            // ── Example ──────────────────────────────────
            TextFormField(
              controller: _exampleCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Example (optional)',
                hintText: 'Usage example, context, or quote',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Pronunciation ────────────────────────────
            TextFormField(
              controller: _pronCtrl,
              decoration: const InputDecoration(
                labelText: 'Pronunciation (optional)',
                hintText: 'e.g., koo-shay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Emoji ────────────────────────────────────
            TextFormField(
              controller: _emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji (optional)',
                hintText: 'e.g., 🥥',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Audio URL ────────────────────────────────
            TextFormField(
              controller: _audioCtrl,
              decoration: const InputDecoration(
                labelText: 'Audio URL (optional)',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Image URL ────────────────────────────────
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Position ─────────────────────────────────
            TextFormField(
              controller: _posCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Position',
                helperText:
                    'Ordering within the theme. Lowest shown first.',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Must be 1 or greater';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Update draft' : 'Create draft'),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                isAdventure
                    ? 'Stored as: ${_category ?? "?"} · ${_difficulty ?? "?"}'
                    : 'Stored as: Language · ${_themeId ?? "no theme"}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
