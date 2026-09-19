import 'package:flutter/material.dart';
import 'base_question_widget.dart';

class TextInputWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final Function(dynamic) onAnswer;
  final bool isAnswered;

  const TextInputWidget({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.onAnswer,
    required this.isAnswered,
  }) : super(key: key);

  @override
  _TextInputWidgetState createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<TextInputWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Report text changes to parent (enables global submit button)
    _controller.addListener(() {
      if (!widget.isAnswered) {
        widget.onAnswer(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

    Widget _buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
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


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
       _buildQuestionCard(widget.questionData['question']),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _controller,
            enabled: !widget.isAnswered,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}