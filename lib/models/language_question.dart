import 'package:kohntri_os_hq/models/question.dart';

class LanguageQuestion {
  final String id;
  final String languageTypeId;
  final String themeId;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String type;
  final String? explanation;
  final int points;
  final int position;
  final String? imageUrl;
  final String? audioUrl;
  final double? trimStart;
  final double? trimEnd;
  final DateTime? createdAt;
  final Map<String, dynamic>? typeData;

  LanguageQuestion({
    required this.id,
    required this.languageTypeId,
    required this.themeId,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.type,
    this.explanation,
    required this.points,
    required this.position,
    this.imageUrl,
    this.audioUrl,
    this.trimStart,
    this.trimEnd,
    this.createdAt,
    this.typeData,
  });

  factory LanguageQuestion.fromSupabase(Map<String, dynamic> json) {
    return LanguageQuestion(
      id: json['id'],
      languageTypeId: json['language_type_id'],
      themeId: json['theme_id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correct_answer_index'],
      type: json['type'],
      explanation: json['explanation'],
      points: json['points'],
      position: json['position'],
      imageUrl: json['image_url'],
      audioUrl: json['audio_url'],
      trimStart: json['trim_start']?.toDouble(),
      trimEnd: json['trim_end']?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      typeData: json['type_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'language_type_id': languageTypeId,
      'theme_id': themeId,
      'question': question,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
      'type': type,
      'explanation': explanation,
      'points': points,
      'position': position,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'trim_start': trimStart,
      'trim_end': trimEnd,
      'created_at': createdAt?.toIso8601String(),
      'type_data': typeData,
    };
  }

  /// Convert to a standard Question for admin display/editing
  Question toQuestion() {
    Map<String, String>? imageUrls;
    if (imageUrl != null) {
      imageUrls = {'0': imageUrl!};
    }

    Map<String, dynamic>? mergedTypeData = {};
    // Copy existing typeData if any (for fill-blank, match-pairs)
    if (typeData != null) {
      mergedTypeData.addAll(typeData!);
    }
    // Add audio/trim info
    if (audioUrl != null) mergedTypeData['audio_url'] = audioUrl!;
    if (trimStart != null) mergedTypeData['trim_start'] = trimStart!;
    if (trimEnd != null) mergedTypeData['trim_end'] = trimEnd!;
    mergedTypeData['original_position'] = position;

    if (mergedTypeData.isEmpty) mergedTypeData = null;

    return Question(
      id: id,
      question: question,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      category: 'Languages', // or use the actual language name? We'll set to 'Languages'
      explanation: explanation ?? '',
      type: QuestionType.fromString(type),
      points: points,
      difficulty: Difficulty.medium, // default, not used
      imageUrls: imageUrls,
      typeData: mergedTypeData,
    );
  }

  /// Create from a standard Question (for saving)
  factory LanguageQuestion.fromQuestion(
    Question q, {
    required String languageTypeId,
    required String themeId,
    required int position,
  }) {
    return LanguageQuestion(
      id: q.id,
      languageTypeId: languageTypeId,
      themeId: themeId,
      question: q.question,
      options: q.options,
      correctAnswerIndex: q.correctAnswerIndex,
      type: q.type.name,
      explanation: q.explanation,
      points: q.points,
      position: position,
      imageUrl: q.imageUrls?.values.firstOrNull,
      audioUrl: q.typeData?['audio_url'],
      trimStart: q.typeData?['trim_start']?.toDouble(),
      trimEnd: q.typeData?['trim_end']?.toDouble(),
      typeData: q.typeData, // preserve full typeData
    );
  }
}