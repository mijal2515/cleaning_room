import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(Supabase.instance.client),
);

/// 로그인 후 방 프로필이 있는지 확인한다. true면 바로 오늘 화면으로 간다.
final bootstrapProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(roomRepositoryProvider);
  return (await repo.hotspots()).isNotEmpty;
});

final hotspotsProvider = FutureProvider<List<Hotspot>>(
  (ref) => ref.watch(roomRepositoryProvider).hotspots(),
);

final profileProvider = FutureProvider<Profile>(
  (ref) => ref.watch(roomRepositoryProvider).profile(),
);

final shopItemsProvider = FutureProvider<List<ShopItem>>(
  (ref) => ref.watch(roomRepositoryProvider).shopItems(),
);
