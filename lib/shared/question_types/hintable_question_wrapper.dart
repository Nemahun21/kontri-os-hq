import 'package:flutter/material.dart';

class HintableQuestionWrapper extends StatelessWidget {
  final Widget child;
  final String explanation;
  final bool hintUsed;
  final bool isAnswered;
  final VoidCallback onHint;

  const HintableQuestionWrapper({
    super.key,
    required this.child,
    required this.explanation,
    required this.hintUsed,
    required this.isAnswered,
    required this.onHint,
  });

  void _showHintDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💡 Hint'),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUseHint = !isAnswered && !hintUsed;
    return Column(
      children: [
        // Hint button row aligned right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canUseHint)
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  onPressed: () {
                    onHint(); // Notify parent that hint was used
                    _showHintDialog(context);
                  },
                  tooltip: 'Use hint (deducts points)',
                )
              else if (hintUsed)
                const Icon(Icons.lightbulb, color: Colors.grey, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }
}