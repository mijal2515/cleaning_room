import 'package:cleaning_coach/data/models.dart';
import 'package:cleaning_coach/features/today/today_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

Hotspot hotspot(String id, List<int> minutes, {DateTime? lastDoneAt}) => Hotspot(
      id: id,
      name: '구역$id',
      tasks: [for (final (i, m) in minutes.indexed) RoomTask(title: '$id-$i', minutes: m)],
      lastDoneAt: lastDoneAt,
    );

void main() {
  final day = DateTime(2026, 10, 28);

  test('오래 손대지 않은 구역부터 한 개씩 고른다', () {
    final picked = pickTodayTasks([
      hotspot('a', [2, 2, 2], lastDoneAt: DateTime.utc(2026, 10, 27)),
      hotspot('b', [2, 2, 2], lastDoneAt: DateTime.utc(2026, 10, 20)),
      hotspot('c', [2, 2, 2]),
      hotspot('d', [2, 2, 2], lastDoneAt: DateTime.utc(2026, 10, 25)),
    ], day);

    expect(picked.map((t) => t.hotspotId), ['c', 'b', 'd']);
  });

  test('합계가 10분을 넘지 않는다', () {
    final picked = pickTodayTasks([
      hotspot('a', [5]),
      hotspot('b', [5]),
      hotspot('c', [3]),
    ], day);

    expect(picked.fold(0, (s, t) => s + t.minutes), lessThanOrEqualTo(10));
    expect(picked.map((t) => t.hotspotId), ['a', 'b']);
  });

  test('같은 날에는 같은 목록, 다음 날에는 다른 일이 나온다', () {
    final spots = [hotspot('a', [2, 2, 2]), hotspot('b', [2, 2, 2]), hotspot('c', [2, 2, 2])];
    final today = pickTodayTasks(spots, day).map((t) => t.title).toList();

    expect(pickTodayTasks(spots, day).map((t) => t.title), today);
    expect(pickTodayTasks(spots, day.add(const Duration(days: 1))).map((t) => t.title), isNot(today));
  });

  test('구역이 적으면 같은 구역의 다른 일을 더 고른다', () {
    final picked = pickTodayTasks([hotspot('a', [2, 2, 2])], day);

    expect(picked, hasLength(3));
    expect(picked.map((t) => t.title).toSet(), hasLength(3));
  });

  test('할 일이 없으면 빈 목록', () {
    expect(pickTodayTasks([], day), isEmpty);
    expect(pickTodayTasks([hotspot('a', [])], day), isEmpty);
  });
}
