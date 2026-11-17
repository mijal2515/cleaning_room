import 'package:flutter/material.dart';

import '../../components/mochi_beaver.dart';

/// 성장 단계에 따라 조금씩 커지는 찹쌀떡 비버 코치.
class CharacterBubble extends StatelessWidget {
  const CharacterBubble({super.key, required this.stage, required this.message});

  final int stage;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = 40.0 + stage * 8;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MochiBeaver(size: size.clamp(64.0, 96.0).toDouble()),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message),
          ),
        ),
      ],
    );
  }
}
