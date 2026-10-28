import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../home/character_bubble.dart';

/// 미니어처 방 꾸미기 자리. 가구 상점과 배치는 다음 단계에서 붙인다(서버의 buy_item, place_item은 준비됨).
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('내 방')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CharacterBubble(
            stage: profile?.characterStage ?? 1,
            message: '코인을 모아서 우리 방을 꾸며 보자. 가구 가게는 곧 열려.',
          ),
          const SizedBox(height: 16),
          if (profile != null) Text('가진 코인 ${profile.coins}', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
