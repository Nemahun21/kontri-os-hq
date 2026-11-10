import 'package:kohntri_os_hq/models/question.dart';

class DailyChallengeQuestion {
  final String id;
  final String dailyChallengeId;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String questionType;
  final String? imageUrl;                    // legacy singular (kept in sync)
  final Map<String, String>? imageUrls;      // new multi-image map
  final String? audioUrl;
  final String? explanation;
  final int points;
  final int position;
  final double? trimStart;
  final double? trimEnd;
  final String category;

  DailyChallengeQuestion({
    required this.id,
    required this.dailyChallengeId,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.questionType,
    this.imageUrl,
    this.imageUrls,
    this.audioUrl,
    this.explanation,
    required this.points,
    required this.position,
    this.trimStart,
    this.trimEnd,
    this.category = 'Daily Challenge',
  });

  factory DailyChallengeQuestion.fromSupabase(Map<String, dynamic> json) {
    Map<String, String>? imageUrls;
    final raw = json['image_urls'];
    if (raw is Map) {
      imageUrls = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (imageUrls == null && json['image_url'] != null) {
      imageUrls = {'0': json['image_url']};
    }

    return DailyChallengeQuestion(
      id: json['id'],
      dailyChallengeId: json['daily_challenge_id'],
      question: json['question'],
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correct_answer_index'],
      questionType: json['question_type'],
      imageUrl: json['image_url'],
      imageUrls: imageUrls,
      audioUrl: json['audio_url'],
      explanation: json['explanation'],
      points: json['points'],
      position: json['position'],
      trimStart: json['trim_start']?.toDouble(),
      trimEnd: json['trim_end']?.toDouble(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'daily_challenge_id': dailyChallengeId,
      'question': question,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
      'question_type': questionType,
      'image_url': imageUrl ?? imageUrls?.values.firstOrNull,
      'image_urls': imageUrls,
      'audio_url': audioUrl,
      'explanation': explanation,
      'points': points,
      'position': position,
      'trim_start': trimStart,
      'trim_end': trimEnd,
    };
  }

  Question toQuestion() {
    final effectiveImageUrls =
        imageUrls ?? (imageUrl != null ? {'0': imageUrl!} : null);

    Map<String, dynamic>? typeData;
    if (audioUrl != null || trimStart != null || trimEnd != null) {
      typeData = {};
      if (audioUrl != null) typeData['audio_url'] = audioUrl!;
      if (trimStart != null) typeData['trim_start'] = trimStart!;
      if (trimEnd != null) typeData['trim_end'] = trimEnd!;
      typeData['original_position'] = position;
    }

    return Question(
      id: id,
      question: question,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      category: 'Daily Challenge',
      explanation: explanation ?? '',
      type: QuestionType.fromString(questionType),
      points: points,
      difficulty: Difficulty.medium,
      imageUrls: effectiveImageUrls,
      typeData: typeData,
      level: position,
    );
  }

  factory DailyChallengeQuestion.fromQuestion(
    Question q, {
    required String dailyChallengeId,
    required int position,
    double? trimStart,
    double? trimEnd,
    int? overridePoints,
  }) {
    return DailyChallengeQuestion(
      id: q.id,
      dailyChallengeId: dailyChallengeId,
      question: q.question,
      options: q.options,
      correctAnswerIndex: q.correctAnswerIndex,
      questionType: q.type.name,
      imageUrl: q.imageUrls?.values.firstOrNull,
      imageUrls: q.imageUrls,
      audioUrl: q.typeData?['audio_url'],
      explanation: q.explanation,
      points: overridePoints ?? q.points,
      position: position,
      trimStart: trimStart ?? q.typeData?['trim_start']?.toDouble() ?? 0.0,
      trimEnd: trimEnd ?? q.typeData?['trim_end']?.toDouble() ?? 0.0,
    );
  }

  DailyChallengeQuestion copyWith({
    int? position,
    int? points,
    double? trimStart,
    double? trimEnd,
    Map<String, String>? imageUrls,
    String? imageUrl,
  }) {
    return DailyChallengeQuestion(
      id: id,
      dailyChallengeId: dailyChallengeId,
      question: question,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      questionType: questionType,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      audioUrl: audioUrl,
      explanation: explanation,
      points: points ?? this.points,
      position: position ?? this.position,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
    );
  }
}