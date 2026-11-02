import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/character_bubble.dart';

/// 미니어처 방 꾸미기: 코인으로 가구를 산다. 배치·그림은 아이템 에셋이 준비되면 붙인다.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, ShopItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(roomRepositoryProvider).buyItem(item.id);
      ref.invalidate(profileProvider);
      ref.invalidate(shopItemsProvider);
      messenger.showSnackBar(SnackBar(content: Text('${item.name} 샀어')));
    } on PostgrestException catch (e) {
      final msg = e.message.contains('not enough')
          ? '코인이 모자라'
          : e.message.contains('already owned')
              ? '이미 가지고 있어'
              : '잠깐 문제가 생겼어. 다시 해볼래?';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final shop = ref.watch(shopItemsProvider);
    final coins = profile?.coins ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('내 방')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CharacterBubble(
            stage: profile?.characterStage ?? 1,
            message: '코인을 모아서 우리 방을 꾸며 보자.',
          ),
          const SizedBox(height: 8),
          Text('가진 코인 $coins', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text('가구 가게', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          switch (shop) {
            AsyncData(:final value) => Column(
                children: [for (final item in value) _ShopTile(item: item, coins: coins, onBuy: () => _buy(context, ref, item))],
              ),
            AsyncError() => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('가게를 불러오지 못했어.', textAlign: TextAlign.center),
              ),
            _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.item, required this.coins, required this.onBuy});

  final ShopItem item;
  final int coins;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= item.price;
    return ListTile(
      title: Text(item.name),
      subtitle: Text('${item.price} 코인'),
      trailing: item.owned
          ? const Chip(label: Text('보유'))
          : SizedBox(
              width: 96,
              child: FilledButton(onPressed: affordable ? onBuy : null, child: const Text('사기')),
            ),
    );
  }
}
