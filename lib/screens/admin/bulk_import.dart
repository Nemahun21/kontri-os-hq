// import 'package:flutter/material.dart';
// import 'package:kohntri_os_hq/models/question.dart';
// import 'package:kohntri_os_hq/services/question_service.dart';
// import 'dart:convert';

// class BulkImportScreen extends StatefulWidget {
//   const BulkImportScreen({super.key});

//   @override
//   State<BulkImportScreen> createState() => _BulkImportScreenState();
// }

// class _BulkImportScreenState extends State<BulkImportScreen> {
//   final QuestionService _questionService = QuestionService();
//   final TextEditingController _jsonController = TextEditingController();
//   bool _isLoading = false;
//   String? _preview;

//   @override
//   void dispose() {
//     _jsonController.dispose();
//     super.dispose();
//   }

//   Future<void> _importFromJson() async {
//     try {
//       final jsonData = jsonDecode(_jsonController.text);
//       List<Question> questions = [];
      
//       if (jsonData is List) {
//         questions = jsonData.map((q) {
//           return Question(
//             id: '',
//             question: q['question'] ?? '',
//             options: List<String>.from(q['options'] ?? []),
//             correctAnswerIndex: q['correctAnswerIndex'] ?? 0,
//             category: q['category'] ?? 'General',
//             explanation: q['explanation'] ?? '',
//             type: QuestionType.values.firstWhere(
//               (e) => e.name == (q['type'] ?? 'multipleChoice'),
//               orElse: () => QuestionType.multipleChoice,
//             ),
//             points: q['points'] ?? 10,
//           );
//         }).toList();
//       }

//       if (questions.isEmpty) throw Exception('No valid questions found');

//       setState(() => _isLoading = true);
//       final success = await _questionService.addQuestions(questions);
      
//       if (success && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Imported ${questions.length} questions!'), backgroundColor: Colors.green),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Invalid JSON: $e'), backgroundColor: Colors.red),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _loadSampleJson() async {
//     final sample = [
//       {
//         'question': 'Sample question?',
//         'options': ['Option A', 'Option B', 'Option C', 'Option D'],
//         'correctAnswerIndex': 0,
//         'category': 'General',
//         'explanation': 'This is a sample explanation',
//         'type': 'multipleChoice',
//         'points': 10,
//       }
//     ];
//     setState(() {
//       _jsonController.text = const JsonEncoder.withIndent('  ').convert(sample);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Bulk Import'),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           TextButton(
//             onPressed: _loadSampleJson,
//             child: const Text('Sample'),
//           ),
//           if (_jsonController.text.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.preview),
//               onPressed: () {
//                 showDialog(
//                   context: context,
//                   builder: (ctx) => AlertDialog(
//                     title: const Text('Preview'),
//                     content: SizedBox(
//                       width: double.maxFinite,
//                       child: SingleChildScrollView(
//                         child: Text(_jsonController.text),
//                       ),
//                     ),
//                     actions: [
//                       TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
//                     ],
//                   ),
//                 );
//               },
//             ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: _jsonController,
//                       maxLines: null,
//                       expands: true,
//                       decoration: InputDecoration(
//                         hintText: 'Paste JSON array of questions here...',
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                         filled: true,
//                         fillColor: Colors.white,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       onPressed: _jsonController.text.isEmpty ? null : _importFromJson,
//                       icon: const Icon(Icons.upload),
//                       label: const Text('IMPORT QUESTIONS'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }
// }