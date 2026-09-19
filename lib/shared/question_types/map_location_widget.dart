// import 'package:flutter/material.dart';

// class MapLocationWidget extends StatelessWidget {
//   final Map<String, dynamic> questionData;
//   final int questionIndex;
//   final Function(String) onAnswer;
//   final bool isAnswered;

//   const MapLocationWidget({
//     Key? key,
//     required this.questionData,
//     required this.questionIndex,
//     required this.onAnswer,
//     required this.isAnswered,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.map, size: 60, color: Colors.blue),
//           const SizedBox(height: 16),
//           const Text(
//             'Map location questions are under development.',
//             style: TextStyle(fontSize: 16, color: Colors.grey),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Correct answer would be: ${questionData['options']?[0] ?? 'unknown'}',
//             style: const TextStyle(fontStyle: FontStyle.italic),
//           ),
//         ],
//       ),
//     );
//   }
// }