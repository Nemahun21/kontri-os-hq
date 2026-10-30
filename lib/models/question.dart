import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

enum QuestionType {
  multipleChoice,
  dragAndDrop,
  trueFalse,
  imageChoice,
  //mapLocation,
  audioGuess,
  textInput,
  fillBlank,
  matchPairs;

  static QuestionType fromString(String? type) {
    if (type == null) return multipleChoice;
    return values.firstWhere(
      (e) => e.name == type,
      orElse: () => multipleChoice,
    );
  }
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.dragAndDrop:
        return 'Drag & Drop';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.imageChoice:
        return 'Image Choice';
      // case QuestionType.mapLocation:
      //   return 'Map Location';
      case QuestionType.audioGuess:
        return 'Audio Guess';
      case QuestionType.textInput:
        return 'Text Input';
      case QuestionType.fillBlank:
        return 'Fill in the Blank';
      case QuestionType.matchPairs:
        return 'Match Pairs';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked;
      case QuestionType.dragAndDrop:
        return Icons.drag_indicator;
      case QuestionType.trueFalse:
        return Icons.thumb_up_alt;
      case QuestionType.imageChoice:
        return Icons.image;
      // case QuestionType.mapLocation:
      //   return Icons.map;
      case QuestionType.audioGuess:
        return Icons.audiotrack;
      case QuestionType.textInput:
        return Icons.keyboard;
      case QuestionType.fillBlank:
        return Icons.space_bar;
      case QuestionType.matchPairs:
        return Icons.compare_arrows;
    }
  }
}

class Question {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String category;
  final String explanation;
  final QuestionType type;
  final Map<String, String>? imageUrls;
  final int points;
  final int? timeLimit;
  final Map<String, dynamic>? typeData;
  final Difficulty difficulty;
  final String? language;
  final String? themeId;
  final int? level;

  // ---- New scenario fields ----
  final String? scenario;
  final String? wrongConsequence;
  final String? culturalContext;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    required this.explanation,
    required this.type,
    this.imageUrls,
    this.points = 10,
    this.timeLimit,
    this.typeData,
    required this.difficulty,
    this.language,
    this.themeId,
    this.level,
    this.scenario,
    this.wrongConsequence,
    this.culturalContext,
  });

  factory Question.fromSupabase(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: (json['correct_answer_index'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'Uncategorized',
      explanation: json['explanation'] ?? '',
      type: QuestionType.fromString(json['type']),
      imageUrls: json['image_urls'] != null
          ? Map<String, String>.from(json['image_urls'])
          : null,
      points: (json['points'] as num?)?.toInt() ?? 10,
      timeLimit: json['time_limit'],
      typeData: json['type_data'] as Map<String, dynamic>?,
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == (json['difficulty'] ?? 'medium'),
        orElse: () => Difficulty.medium,
      ),
      language: json['language'],
      themeId: json['theme_id'],
      level: json['level'] != null ? (json['level'] as num).toInt() : null,
      scenario: json['scenario'] as String?,
      wrongConsequence: json['wrong_consequence'] as String?,
      culturalContext: json['cultural_context'] as String?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'question': question,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
      'category': category,
      'explanation': explanation,
      'type': type.name,
      'image_urls': imageUrls,
      'points': points,
      'time_limit': timeLimit,
      'type_data': typeData,
      'difficulty': difficulty.name,
      'language': language,
      'theme_id': themeId,
      'level': level,
      // ---- New fields ----
      'scenario': scenario,
      'wrong_consequence': wrongConsequence,
      'cultural_context': culturalContext,
    };
  }

  Question copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? category,
    String? explanation,
    QuestionType? type,
    Map<String, String>? imageUrls,
    int? points,
    int? timeLimit,
    Map<String, dynamic>? typeData,
    Difficulty? difficulty,
    String? language,
    String? themeId,
    int? level,
    String? scenario,
    String? wrongConsequence,
    String? culturalContext,
  }) {
    return Question(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      category: category ?? this.category,
      explanation: explanation ?? this.explanation,
      type: type ?? this.type,
      imageUrls: imageUrls ?? this.imageUrls,
      points: points ?? this.points,
      timeLimit: timeLimit ?? this.timeLimit,
      typeData: typeData ?? this.typeData,
      difficulty: difficulty ?? this.difficulty,
      language: language ?? this.language,
      themeId: themeId ?? this.themeId,
      level: level ?? this.level,
      scenario: scenario ?? this.scenario,
      wrongConsequence: wrongConsequence ?? this.wrongConsequence,
      culturalContext: culturalContext ?? this.culturalContext,
    );
  }
}
