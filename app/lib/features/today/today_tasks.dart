import '../../data/models.dart';

/// 방 프로필에서 사진 없이 오늘 할 일을 고른다.
///
/// 오래 손대지 않은 구역부터 한 개씩 뽑고, 같은 구역 안에서는 날짜에 따라 돌아가며 고른다.
/// 같은 날에는 몇 번을 열어도 같은 목록이 나온다. 합계는 [maxMinutes]분을 넘지 않는다.
List<TodayTask> pickTodayTasks(
  List<Hotspot> hotspots,
  DateTime day, {
  int count = 3,
  int maxMinutes = 10,
}) {
  final order = [...hotspots.indexed]..sort((a, b) {
      final da = a.$2.lastDoneAt;
      final db = b.$2.lastDoneAt;
      if (da != db) {
        if (da == null) return -1;
        if (db == null) return 1;
        final byDate = da.compareTo(db);
        if (byDate != 0) return byDate;
      }
      return a.$1.compareTo(b.$1);
    });
  final dayNumber = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  final picked = <TodayTask>[];
  var total = 0;
  // 구역이 할 일 수보다 적으면 한 바퀴 더 돌며 같은 구역의 다른 일을 고른다.
  for (var round = 0; round < 5 && picked.length < count; round++) {
    for (final (i, hotspot) in order) {
      if (picked.length >= count) break;
      if (round >= hotspot.tasks.length) continue;
      final task = hotspot.tasks[(dayNumber + i + round) % hotspot.tasks.length];
      if (total + task.minutes > maxMinutes) continue;
      picked.add(TodayTask(title: task.title, minutes: task.minutes, area: hotspot.name, hotspotId: hotspot.id));
      total += task.minutes;
    }
  }
  return picked;
}
