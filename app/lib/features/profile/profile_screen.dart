import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('나')),
      body: ListView(
        children: [
          if (profile != null)
            ListTile(
              title: Text('코인 ${profile.coins}'),
              subtitle: Text('연속 ${profile.streakDays}일 · 친구 ${profile.characterStage}단계'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('방 다시 찍기 (주간 점검)'),
            subtitle: const Text('방이 많이 달라졌을 때만 찍으면 돼요'),
            onTap: () => context.push('/scan/weekly'),
          ),
          const ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('게스트로 쓰는 중'),
            subtitle: Text('휴대폰을 바꿔도 이어 쓰려면 Google 계정을 연결하세요 (준비 중)'),
          ),
        ],
      ),
    );
  }
}
