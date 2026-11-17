import 'package:flutter/material.dart';

import 'sunny_friend.dart';

class CharacterBubble extends StatelessWidget {
  const CharacterBubble({
    super.key,
    required this.stage,
    required this.message,
  });
  final int stage;
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          const SunnyFriend(size: 132),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              height: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '나의 청소 친구 · $stage단계',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}
