class LessonVocabulary {
  final String id;
  final String contentType; // 'adventure' | 'language'
  final String? category;   // 'History', 'Food', 'Sports' (adventure only)
  final String? themeId;    // theme UUID (language only)
   final String? difficulty;
  final String term;
  final String definition;
  final String? pronunciation;
  final String? example;
  final String? emoji;
  final String? audioUrl;
  final String? imageUrl;
  final int position;

  LessonVocabulary({
    required this.id,
    required this.contentType,
    this.category,
    this.themeId,
    this.difficulty,
    required this.term,
    required this.definition,
    this.pronunciation,
    this.example,
    this.emoji,
    this.audioUrl,
    this.imageUrl,
    this.position = 1,
  });

  factory LessonVocabulary.fromSupabase(Map<String, dynamic> json) {
    return LessonVocabulary(
      id: json['id'] ?? '',
      contentType: json['content_type'] ?? 'adventure',
      category: json['category'],
      themeId: json['theme_id'],
      difficulty: json['difficulty'],
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
      pronunciation: json['pronunciation'],
      example: json['example'],
      emoji: json['emoji'],
      audioUrl: json['audio_url'],
      imageUrl: json['image_url'],
      position: json['position'] ?? 1,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'content_type': contentType,
      'category': category,
      'theme_id': themeId,
      'difficulty': difficulty,
      'term': term,
      'definition': definition,
      'pronunciation': pronunciation,
      'example': example,
      'emoji': emoji,
      'audio_url': audioUrl,
      'image_url': imageUrl,
      'position': position,
    };
  }
}