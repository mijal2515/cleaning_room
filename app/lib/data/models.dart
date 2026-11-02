/// 서버(Supabase)와 주고받는 데이터. JSON 키는 DB·Edge Function과 같은 snake_case를 쓴다.
library;

class RoomTask {
  const RoomTask({required this.title, required this.minutes});

  final String title;
  final int minutes;

  factory RoomTask.fromJson(Map<String, dynamic> json) =>
      RoomTask(title: json['title'] as String, minutes: (json['minutes'] as num).toInt());
}

/// 방 프로필의 한 구역 (예: 책상 위). 매일의 할 일은 여기서 뽑는다.
class Hotspot {
  const Hotspot({
    required this.id,
    required this.name,
    required this.tasks,
    this.typicalItems = const [],
    this.lastDoneAt,
  });

  final String id;
  final String name;
  final List<String> typicalItems;
  final List<RoomTask> tasks;
  final DateTime? lastDoneAt;

  factory Hotspot.fromRow(Map<String, dynamic> row) => Hotspot(
        id: row['id'] as String,
        name: row['name'] as String,
        typicalItems: List<String>.from(row['typical_items'] as List? ?? const []),
        tasks: [
          for (final t in row['tasks'] as List? ?? const [])
            RoomTask.fromJson(Map<String, dynamic>.from(t as Map)),
        ],
        lastDoneAt: row['last_done_at'] == null ? null : DateTime.parse(row['last_done_at'] as String),
      );
}

/// 오늘 화면에 보여줄 할 일 하나.
class TodayTask {
  const TodayTask({required this.title, required this.minutes, required this.area, this.hotspotId});

  final String title;
  final int minutes;
  final String area;
  final String? hotspotId;

  TodayTask withHotspot(String? id) => TodayTask(title: title, minutes: minutes, area: area, hotspotId: id);

  Map<String, dynamic> toJson({required bool done}) => {'title': title, 'minutes': minutes, 'done': done};
}

class RoomAnalysis {
  const RoomAnalysis({
    required this.isRoom,
    required this.messiness,
    required this.summary,
    required this.hotspotNames,
    required this.todayTasks,
    required this.encouragement,
  });

  final bool isRoom;
  final int messiness;
  final String summary;
  final List<String> hotspotNames;
  final List<TodayTask> todayTasks;
  final String encouragement;

  factory RoomAnalysis.fromJson(Map<String, dynamic> json) {
    if (json['is_room'] != true) {
      return const RoomAnalysis(
          isRoom: false, messiness: 0, summary: '', hotspotNames: [], todayTasks: [], encouragement: '');
    }
    return RoomAnalysis(
      isRoom: true,
      messiness: (json['messiness'] as num).toInt(),
      summary: json['summary'] as String,
      hotspotNames: [for (final h in json['hotspots'] as List) (h as Map)['name'] as String],
      todayTasks: [
        for (final t in json['today_tasks'] as List)
          TodayTask(
            title: (t as Map)['title'] as String,
            minutes: (t['minutes'] as num).toInt(),
            area: t['area'] as String,
          ),
      ],
      encouragement: json['encouragement'] as String,
    );
  }
}

class Reward {
  const Reward({
    required this.coinsAwarded,
    required this.coins,
    required this.streakDays,
    required this.characterStage,
    this.praise,
  });

  final int coinsAwarded;
  final int coins;
  final int streakDays;
  final int characterStage;
  final String? praise;

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        coinsAwarded: (json['coins_awarded'] as num).toInt(),
        coins: (json['coins'] as num).toInt(),
        streakDays: (json['streak_days'] as num).toInt(),
        characterStage: (json['character_stage'] as num).toInt(),
        praise: (json['compare'] as Map?)?['praise'] as String?,
      );
}

/// 가구 상점의 아이템 하나. owned면 이미 가진 것.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.slot,
    required this.price,
    required this.name,
    required this.owned,
  });

  final String id;
  final String slot;
  final int price;
  final String name;
  final bool owned;
}

class Profile {
  const Profile({required this.coins, required this.streakDays, required this.characterStage});

  final int coins;
  final int streakDays;
  final int characterStage;

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        coins: (row['coins'] as num).toInt(),
        streakDays: (row['streak_days'] as num).toInt(),
        characterStage: (row['character_stage'] as num).toInt(),
      );
}
