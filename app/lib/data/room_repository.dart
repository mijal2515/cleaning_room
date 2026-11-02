import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/time.dart';
import 'models.dart';

/// 방 분석을 부르는 경우. 서버의 sessions.kind와 같다.
enum AnalyzeMode { register, weekly, now }

/// 방 분석이 실패한 이유. 화면에서 안내 문구를 고르는 데 쓴다.
enum AnalyzeFailure { dailyLimit, notRoom, refused, network, server }

class AnalyzeException implements Exception {
  const AnalyzeException(this.reason);
  final AnalyzeFailure reason;
}

class RoomRepository {
  RoomRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<List<Hotspot>> hotspots() async {
    final rows = await _client
        .from('room_hotspots')
        .select()
        .eq('zone', 'room')
        .order('sort_order');
    return [for (final r in rows) Hotspot.fromRow(r)];
  }

  /// 상점 아이템 전체와, 그중 내가 가진 것 표시.
  Future<List<ShopItem>> shopItems() async {
    final items = await _client.from('items').select('id, slot, price, name').eq('active', true).order('price');
    final owned = await _client.from('inventory').select('item_id');
    final ownedIds = {for (final r in owned) r['item_id'] as String};
    return [
      for (final r in items)
        ShopItem(
          id: r['id'] as String,
          slot: r['slot'] as String,
          price: (r['price'] as num).toInt(),
          name: r['name'] as String,
          owned: ownedIds.contains(r['id']),
        ),
    ];
  }

  /// 코인으로 아이템을 산다. 가격·코인·중복은 서버(buy_item)가 검증한다.
  Future<void> buyItem(String id) => _client.rpc('buy_item', params: {'p_item_id': id});

  Future<Profile> profile() async {
    final row = await _client.from('profiles').select('coins, streak_days, character_stage').single();
    return Profile.fromRow(row);
  }

  /// 오늘(한국 날짜) 할 일을 하나라도 끝낸 적이 있는지.
  Future<bool> doneToday() async {
    final since = seoulMidnightUtc(seoulToday()).toIso8601String();
    final rows = await _client
        .from('sessions')
        .select('id')
        .eq('kind', 'daily')
        .gt('tasks_completed', 0)
        .gte('completed_at', since)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<RoomAnalysis> analyze(Uint8List image, AnalyzeMode mode) async {
    try {
      final res = await _client.functions.invoke('analyze-room', body: {
        'mode': mode.name,
        'image': base64Encode(image),
        'media_type': mediaTypeOf(image),
      });
      final analysis = RoomAnalysis.fromJson(Map<String, dynamic>.from(res.data as Map));
      if (!analysis.isRoom) throw const AnalyzeException(AnalyzeFailure.notRoom);
      return analysis;
    } on FunctionException catch (e) {
      throw AnalyzeException(switch (e.status) {
        429 => AnalyzeFailure.dailyLimit,
        422 => AnalyzeFailure.refused,
        _ => AnalyzeFailure.server,
      });
    } on AuthException {
      throw const AnalyzeException(AnalyzeFailure.server);
    } on Exception catch (e) {
      if (e is AnalyzeException) rethrow;
      throw const AnalyzeException(AnalyzeFailure.network);
    }
  }

  /// 체크한 할 일을 보내고 코인을 받는다. 사진은 선택이다.
  Future<Reward> complete(List<TodayTask> tasks, Set<int> doneIndexes) async {
    final res = await _client.functions.invoke('complete-session', body: {
      'kind': 'daily',
      'tasks': [for (var i = 0; i < tasks.length; i++) tasks[i].toJson(done: doneIndexes.contains(i))],
    });
    final reward = Reward.fromJson(Map<String, dynamic>.from(res.data as Map));

    final doneHotspots = {
      for (final i in doneIndexes)
        if (tasks[i].hotspotId != null) tasks[i].hotspotId!,
    };
    if (doneHotspots.isNotEmpty) {
      await _client
          .from('room_hotspots')
          .update({'last_done_at': DateTime.now().toUtc().toIso8601String()})
          .inFilter('id', doneHotspots.toList());
    }
    return reward;
  }
}

/// 사진 앞부분의 서명으로 형식을 판단한다. image_picker는 대부분 JPEG로 준다.
String mediaTypeOf(Uint8List bytes) {
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
