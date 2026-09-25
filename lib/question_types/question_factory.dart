import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/question_types/audio_enabled_question.dart';
import 'package:kohntri_os_hq/question_types/audio_guess_widget.dart';
import 'package:kohntri_os_hq/question_types/hintable_question_wrapper.dart';
import 'multiple_choice_widget.dart';
import 'true_false_widget.dart';
import 'drag_and_drop_widget.dart';
import 'text_input_widget.dart';
import 'image_choice_widget.dart';
import 'match_pairs_widget.dart';
import 'fill_blank_widget.dart';

class QuestionFactory {
  static Widget createQuestion({
    required Map<String, dynamic> questionData,
    required int questionIndex,
    required Function(dynamic) onAnswer,
    required bool isAnswered,
    int? selectedIndex,
    
    bool isDragCorrect = false,
    String? droppedAnswer,
    bool hintUsed = false, // new
    VoidCallback? onHint,
  }) {
    final type = _getQuestionType(questionData['type']);
    print('Creating question of type: $type');
    print('QuestionData keys: ${questionData.keys}');

    // 1. Build the base widget based on type
    Widget baseWidget;

    switch (type) {
      case QuestionType.multipleChoice:
        baseWidget = MultipleChoiceWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          selectedIndex: selectedIndex,
        );
        break;

      case QuestionType.trueFalse:
        baseWidget = TrueFalseWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          selectedIndex: selectedIndex,
          
        );
        break;

      case QuestionType.dragAndDrop:
        baseWidget = DragAndDropWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          isCorrect: isDragCorrect,
          droppedAnswer: droppedAnswer,
        );
        break;

      case QuestionType.textInput:
        baseWidget = TextInputWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
        );
        break;

      case QuestionType.imageChoice:
        baseWidget = ImageChoiceWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          selectedIndex: selectedIndex,
        );
        break;

      case QuestionType.matchPairs:
        print('Returning MatchPairsWidget');
        baseWidget = MatchPairsWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          
        );
        break;

      case QuestionType.audioGuess:
        baseWidget = AudioGuessWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
        );
        break;

      case QuestionType.fillBlank:
        final typeData =
            questionData['type_data'] as Map<String, dynamic>? ?? {};
        final sentenceParts =
            (typeData['sentenceParts'] as List?)?.cast<String?>() ?? [];
        final wordBankData =
            (typeData['wordBank'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final wordBank = wordBankData
            .map(
              (e) => FillBlankWord(
                id: e['id'] as String,
                text: e['text'] as String,
              ),
            )
            .toList();
        final correctAnswersData =
            typeData['correctAnswers'] as Map<String, dynamic>? ?? {};
        final correctAnswers = correctAnswersData.map(
          (key, value) => MapEntry(int.parse(key), value as String),
        );

        baseWidget = DragAndDropFillBlank(
          question: questionData['question'] as String?,
          sentenceParts: sentenceParts,
          wordBank: wordBank,
          correctAnswers: correctAnswers,
          
          onStateChanged: (filledMap) {
            onAnswer({'type': 'fillBlank', 'filled': filledMap});
          },
        );
        break;

      default:
        baseWidget = MultipleChoiceWidget(
          questionData: questionData,
          questionIndex: questionIndex,
          onAnswer: onAnswer,
          isAnswered: isAnswered,
          selectedIndex: selectedIndex,
        );
    }

    // 2. Check if there's an audio URL in type_data
    final typeData = questionData['type_data'] as Map<String, dynamic>?;
    final audioUrl = typeData?['audio_url'] as String?;
    final trimStart = (typeData?['trim_start'] as num?)?.toDouble();
    final trimEnd = (typeData?['trim_end'] as num?)?.toDouble();
    // 3. Wrap with AudioEnabledQuestion if audio exists
    if (audioUrl != null &&
        audioUrl.isNotEmpty &&
        type != QuestionType.audioGuess) {
      return AudioEnabledQuestion(
        audioUrl: audioUrl,

        trimStart: trimStart,
        trimEnd: trimEnd,
        child: baseWidget,
      );
    }

    final explanation = questionData['explanation'] as String?;
    if (explanation != null && explanation.isNotEmpty && onHint != null) {
      return HintableQuestionWrapper(
        explanation: explanation,
        hintUsed: hintUsed,
        isAnswered: isAnswered,
        onHint: onHint,
        child: baseWidget,
      );
    }

    // 4. Otherwise return the base widget as is
    return baseWidget;
  }

  static QuestionType _getQuestionType(String? type) {
    switch (type) {
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'trueFalse':
        return QuestionType.trueFalse;
      case 'dragAndDrop':
        return QuestionType.dragAndDrop;
      case 'textInput':
        return QuestionType.textInput;
      case 'imageChoice':
        return QuestionType.imageChoice;
      case 'matchPairs':
        return QuestionType.matchPairs;
      case 'fillBlank':
        return QuestionType.fillBlank;
      case 'audioGuess':
        return QuestionType.audioGuess;
      default:
        return QuestionType.multipleChoice;
    }
  }
}
