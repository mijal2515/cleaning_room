import 'package:flutter/material.dart';

/// 캐릭터 자리. 그림이 나오기 전까지는 단계에 따라 크기만 달라지는 동그라미로 둔다.
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
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
          child: Icon(Icons.cruelty_free, color: colors.onPrimaryContainer, size: size * 0.6),
        ),
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
