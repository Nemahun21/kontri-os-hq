// import 'package:flutter/material.dart';

// class AddQuestionScreen extends StatefulWidget {
//   const AddQuestionScreen({super.key});

//   @override
//   State<AddQuestionScreen> createState() => _AddQuestionScreenState();
// }

// class _AddQuestionScreenState extends State<AddQuestionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _idController = TextEditingController();
//   final _questionController = TextEditingController();
//   final _optionsController = TextEditingController();
//   final _correctAnswerController = TextEditingController();
//   final _categoryController = TextEditingController();
//   final _explanationController = TextEditingController();
  
//   String _selectedType = 'multipleChoice';
//   String _selectedDifficulty = 'easy';
//   bool _isLoading = false;

//   final List<String> _questionTypes = [
//     'multipleChoice',
//     'trueFalse',
//     'dragAndDrop',
//     'textInput',
//     'imageChoice'
//   ];

//   final List<String> _difficulties = ['easy', 'medium', 'hard'];

//   @override
//   void dispose() {
//     _idController.dispose();
//     _questionController.dispose();
//     _optionsController.dispose();
//     _correctAnswerController.dispose();
//     _categoryController.dispose();
//     _explanationController.dispose();
//     super.dispose();
//   }

// Future<void> _saveQuestion() async {
//   if (!_formKey.currentState!.validate()) return;

//   setState(() => _isLoading = true);

//   try {
//     Map<String, dynamic> questionData = {
//       'id': _idController.text.trim(),
//       'type': _selectedType,
//       'question': _questionController.text.trim(),
//       'category': _categoryController.text.trim(),
//       'difficulty': _selectedDifficulty,
//       'explanation': _explanationController.text.trim(),
//     };

//     // Add type-specific fields
//     if (_selectedType == 'multipleChoice') {
//       final optionsList = _optionsController.text
//           .split(',')
//           .map((e) => e.trim())
//           .where((e) => e.isNotEmpty)
//           .toList();
//       if (optionsList.length < 2) {
//         throw Exception('At least two options required for multiple choice');
//       }
//       questionData['options'] = optionsList;
//       questionData['correct_answer_index'] = 
//           int.tryParse(_correctAnswerController.text) ?? 0;
//     } else if (_selectedType == 'trueFalse') {
//       // For true/false, we provide the standard options
//       questionData['options'] = ['True', 'False'];
//       questionData['correct_answer_index'] = 
//           _correctAnswerController.text.toLowerCase() == 'true' ? 0 : 1;
//     } else {
//       // For other types (fillBlank, etc.)
//       final optionsList = _optionsController.text
//           .split(',')
//           .map((e) => e.trim())
//           .where((e) => e.isNotEmpty)
//           .toList();
//       questionData['options'] = optionsList;
//       questionData['correct_answer'] = _correctAnswerController.text.trim();
//     }

//     // Insert into Supabase
//     await supabase.from('questions').insert(questionData);

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('✅ Question added!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       Navigator.pop(context, true);
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
//     );
//   } finally {
//     if (mounted) setState(() => _isLoading = false);
//   }
// }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Add Question'),
//         backgroundColor: const Color(0xFF1A5276),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _idController,
//                 decoration: const InputDecoration(
//                   labelText: 'Question ID',
//                   hintText: 'e.g., krio_1, history_2',
//                 ),
//                 validator: (v) => v!.isEmpty ? 'Required' : null,
//               ),
//               const SizedBox(height: 16),
              
//               DropdownButtonFormField(
//                 value: _selectedType,
//                 items: _questionTypes.map((type) {
//                   return DropdownMenuItem(value: type, child: Text(type));
//                 }).toList(),
//                 onChanged: (v) => setState(() => _selectedType = v!),
//                 decoration: const InputDecoration(labelText: 'Question Type'),
//               ),
//               const SizedBox(height: 16),
              
//               TextFormField(
//                 controller: _questionController,
//                 maxLines: 3,
//                 decoration: const InputDecoration(labelText: 'Question'),
//                 validator: (v) => v!.isEmpty ? 'Required' : null,
//               ),
//               const SizedBox(height: 16),
              
//               if (_selectedType != 'trueFalse') ...[
//                 TextFormField(
//                   controller: _optionsController,
//                   decoration: const InputDecoration(
//                     labelText: 'Options (comma separated)',
//                     hintText: 'Option1, Option2, Option3, Option4',
//                   ),
//                   validator: (v) => v!.isEmpty ? 'Required' : null,
//                 ),
//                 const SizedBox(height: 16),
//               ],
              
//               TextFormField(
//                 controller: _correctAnswerController,
//                 decoration: InputDecoration(
//                   labelText: _selectedType == 'multipleChoice'
//                       ? 'Correct Answer Index (0-3)'
//                       : 'Correct Answer',
//                 ),
//                 validator: (v) => v!.isEmpty ? 'Required' : null,
//               ),
//               const SizedBox(height: 16),
              
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: const InputDecoration(labelText: 'Category'),
//                 validator: (v) => v!.isEmpty ? 'Required' : null,
//               ),
//               const SizedBox(height: 16),
              
//               DropdownButtonFormField(
//                 value: _selectedDifficulty,
//                 items: _difficulties.map((d) {
//                   return DropdownMenuItem(value: d, child: Text(d));
//                 }).toList(),
//                 onChanged: (v) => setState(() => _selectedDifficulty = v!),
//                 decoration: const InputDecoration(labelText: 'Difficulty'),
//               ),
//               const SizedBox(height: 16),
              
//               TextFormField(
//                 controller: _explanationController,
//                 maxLines: 2,
//                 decoration: const InputDecoration(labelText: 'Explanation'),
//               ),
//               const SizedBox(height: 30),
              
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _saveQuestion,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF27AE60),
//                   ),
//                   child: _isLoading
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : const Text('ADD QUESTION'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }