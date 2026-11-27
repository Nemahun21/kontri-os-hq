import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/widgets/learning_question_card.dart';

class QuestionCard extends StatelessWidget {
  final String questionId;
  final Map<String, dynamic> questionData;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const QuestionCard({
    Key? key,
    required this.questionId,
    required this.questionData,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = {...questionData,'id':questionId};
    final typeData = data['type_data'] is Map
        ? Map<String,dynamic>.from(data['type_data'] as Map) : <String,dynamic>{};
    for(final k in ['audio_url','trim_start','trim_end']) {
      if(data[k]!=null) typeData[k]=data[k];
    }
    data['type_data']=typeData;
    if(data['image_urls']==null && data['image_url'] is String) {
      data['image_urls']={'0':data['image_url'] as String};
    }
    if(data['type']==null) data['type']=data['question_type'];
    if(data['level']==null) data['level']=data['position'];
    return LearningQuestionCard(question:Question.fromSupabase(data),onEdit:onTap,onDelete:onDelete);
  }
}