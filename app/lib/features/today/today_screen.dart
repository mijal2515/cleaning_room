import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/character_bubble.dart';
import 'today_providers.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final Set<int> _done = {};
  bool _sending = false;
  Reward? _reward;

  Future<void> _complete(List<TodayTask> tasks) async {
    setState(() => _sending = true);
    try {
      final reward = await ref.read(roomRepositoryProvider).complete(tasks, _done);
      ref.invalidate(profileProvider);
      ref.invalidate(doneTodayProvider);
      setState(() => _reward = reward);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 눌러주세요.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 새 사진으로 할 일이 바뀌면 체크와 보상 표시를 처음부터 다시 한다.
    ref.listen(todayPlanProvider, (_, _) => setState(() {
          _done.clear();
          _reward = null;
        }));

    final plan = ref.watch(todayPlanProvider);
    final profile = ref.watch(profileProvider).value;
    final doneToday = ref.watch(doneTodayProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 할 일'),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('코인 ${profile.coins} · 연속 ${profile.streakDays}일')),
            ),
        ],
      ),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(onPressed: () => ref.invalidate(hotspotsProvider), child: const Text('불러오지 못했어요. 다시 시도')),
        ),
        data: (plan) {
          final stage = profile?.characterStage ?? 1;
          if (plan.tasks.isEmpty) {
            return _Padded(children: [
              CharacterBubble(stage: stage, message: '아직 방을 몰라서 할 일을 못 골랐어. 방 사진을 한 번만 보여줄래?'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.push('/scan/register'), child: const Text('방 등록하기')),
            ]);
          }

          final reward = _reward;
          if (reward != null) return _RewardView(reward: reward, stage: stage);
          if (doneToday && !plan.fromAi) {
            return _Padded(children: [
              CharacterBubble(stage: stage, message: '오늘 할 일은 끝났어. 내일 또 골라 둘게.'),
              const SizedBox(height: 16),
              _MessyButton(),
            ]);
          }

          final minutes = plan.tasks.fold(0, (sum, t) => sum + t.minutes);
          return _Padded(children: [
            CharacterBubble(stage: stage, message: plan.message ?? '오늘은 이것만 하자. $minutes분이면 끝나.'),
            const SizedBox(height: 16),
            for (final (i, task) in plan.tasks.indexed)
              CheckboxListTile(
                value: _done.contains(i),
                onChanged: _sending ? null : (v) => setState(() => v! ? _done.add(i) : _done.remove(i)),
                title: Text(task.title),
                subtitle: Text('${task.area} · ${task.minutes}분'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _done.isEmpty || _sending ? null : () => _complete(plan.tasks),
              child: Text('다 했어 (${_done.length}/${plan.tasks.length})'),
            ),
            const SizedBox(height: 8),
            _MessyButton(),
          ]);
        },
      ),
    );
  }
}

class _RewardView extends StatelessWidget {
  const _RewardView({required this.reward, required this.stage});

  final Reward reward;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = reward.praise ??
        (reward.coinsAwarded > 0 ? '고마워, 방이 한결 가벼워졌어.' : '오늘 받을 수 있는 코인은 다 받았어. 그래도 정말 잘했어.');
    return _Padded(children: [
      CharacterBubble(stage: reward.characterStage, message: message),
      const SizedBox(height: 24),
      Text('+${reward.coinsAwarded} 코인', style: text.displaySmall, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('가진 코인 ${reward.coins} · 연속 ${reward.streakDays}일째', textAlign: TextAlign.center),
      if (reward.characterStage > stage) ...[
        const SizedBox(height: 8),
        Text('친구가 한 단계 자랐어요!', style: text.titleMedium, textAlign: TextAlign.center),
      ],
    ]);
  }
}

class _MessyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => context.push('/scan/now'),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('오늘 너무 지저분해'),
      );
}

class _Padded extends StatelessWidget {
  const _Padded({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: children);
}
