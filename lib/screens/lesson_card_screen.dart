import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/lesson_vocab.dart';
import 'package:kohntri_os_hq/services/lesson_vocab_service.dart';

class LessonCardScreen extends StatefulWidget {
  final String contentType; // 'adventure' or 'language'
  final String? category;   // for adventure
  final String? themeId;    // for language
  final String title;       // e.g., "History" or "Krio • Greetings"
  final VoidCallback onComplete; // what happens after lesson

  const LessonCardScreen({
    super.key,
    required this.contentType,
    this.category,
    this.themeId,
    required this.title,
    required this.onComplete,
  });

  @override
  State<LessonCardScreen> createState() => _LessonCardScreenState();
}

class _LessonCardScreenState extends State<LessonCardScreen> {
  final LessonVocabularyService _service = LessonVocabularyService();
  List<LessonVocabulary> _items = [];
  bool _isLoading = true;
  int _currentIndex = 0;

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
        category: widget.category,
        themeId: widget.themeId,
      );
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading lesson: $e');
      setState(() => _isLoading = false);
    }
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onComplete();
    }
  }

  void _previous() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      // No lesson content – skip straight to quiz
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete();
      });
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final item = _items[_currentIndex];
    final progress = (_currentIndex + 1) / _items.length;
    final isLanguage = widget.contentType == 'language';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: widget.onComplete,
            child: const Text('Skip to Quiz'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isLanguage ? "Word" : "Term"} ${_currentIndex + 1} of ${_items.length}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ],
              ),
            ),

            // Card
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade50, Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Optional image
                          if (item.imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                item.imageUrl!,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Emoji + Term
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (item.emoji != null) ...[
                                Text(item.emoji!, style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  item.term,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A5276),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),

                          // Pronunciation (language only)
                          if (isLanguage &&
                              item.pronunciation != null &&
                              item.pronunciation!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '/${item.pronunciation}/',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.amber[800],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Definition
                          Text(
                            item.definition,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2C3E50),
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Example
                          if (item.example != null && item.example!.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '"${item.example}"',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          // Audio button
                          if (item.audioUrl != null) ...[
                            const SizedBox(height: 16),
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 32),
                              color: Colors.blue[700],
                              onPressed: () {
                                // TODO: play audio
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previous,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        _currentIndex == _items.length - 1 ? 'Start Quiz' : 'Next',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}