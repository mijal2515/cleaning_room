import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/providers.dart';
import '../home/character_bubble.dart';
import '../home/gentle_heading.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final profile = state.value;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('나의 기록')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const GentleHeading(eyebrow: '나', title: '차곡차곡 쌓인\n나의 작은 습관.'),
              CharacterBubble(
                stage: profile?.characterStage ?? 1,
                message: '완벽하지 않아도 괜찮아. 우리 조금씩 해보자.',
              ),
              const SizedBox(height: 24),
              if (profile != null)
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final stat in [
                        (Icons.toll_rounded, '${profile.coins}', '모은 코인'),
                        (
                          Icons.local_fire_department_outlined,
                          '${profile.streakDays}일',
                          '연속 정리',
                        ),
                        (
                          Icons.auto_awesome_rounded,
                          'Lv.${profile.characterStage}',
                          '친구의 성장',
                        ),
                      ])
                        SizedBox(
                          width: constraints.maxWidth < 400
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    stat.$1,
                                    color: colors.onSurface,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    stat.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(stat.$3),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else if (state.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('기록을 다시 불러오기'),
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              const SizedBox(height: 20),
              Text('나의 공간 관리', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: colors.onSurface,
                  ),
                  title: const Text('방의 새로운 모습'),
                  subtitle: const Text('방이 달라졌다면 주간 점검을 해봐'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/scan/weekly'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('로그아웃'),
                  subtitle: Text(
                    Supabase.instance.client.auth.currentUser?.email ?? '',
                  ),
                  onTap: () => ref.read(roomRepositoryProvider).signOut(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
