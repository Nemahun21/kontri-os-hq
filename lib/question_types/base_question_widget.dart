import 'package:flutter/material.dart';

abstract class BaseQuestionWidget extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final bool isAnswered;
  final Function(dynamic) onAnswer;
  
  const BaseQuestionWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.isAnswered,
    required this.onAnswer,
  }) : super(key: key);
  
  Widget buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  Widget buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A5276).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        questionData['category'] ?? 'Quiz',
        style: const TextStyle(
          color: Color(0xFF1A5276),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}