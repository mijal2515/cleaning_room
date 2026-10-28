import 'dart:typed_data';

import 'package:cleaning_coach/core/time.dart';
import 'package:cleaning_coach/data/models.dart';
import 'package:cleaning_coach/data/room_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('방 분석 응답을 읽는다', () {
    final a = RoomAnalysis.fromJson({
      'is_room': true,
      'messiness': 62,
      'summary': '책상 위에 컵과 종이가 쌓여 있어.',
      'hotspots': [
        {'name': '책상 위', 'typical_items': ['컵'], 'tasks': []},
      ],
      'today_tasks': [
        {'title': '컵을 싱크대로 옮기기', 'area': '책상 위', 'minutes': 1},
      ],
      'encouragement': '컵부터 하자.',
      'session_id': 'x',
    });

    expect(a.isRoom, isTrue);
    expect(a.hotspotNames, ['책상 위']);
    expect(a.todayTasks.single.title, '컵을 싱크대로 옮기기');
  });

  test('방이 아니면 빈 결과', () {
    expect(RoomAnalysis.fromJson({'is_room': false}).isRoom, isFalse);
  });

  test('보상 응답에서 AI 칭찬을 꺼낸다', () {
    final r = Reward.fromJson({
      'session_id': 'x',
      'coins_awarded': 50,
      'coins': 120,
      'streak_days': 3,
      'character_stage': 2,
      'compare': {'praise': '책상이 넓어졌어.'},
    });

    expect(r.coinsAwarded, 50);
    expect(r.praise, '책상이 넓어졌어.');
    expect(
      Reward.fromJson({'coins_awarded': 0, 'coins': 0, 'streak_days': 0, 'character_stage': 1, 'compare': null}).praise,
      isNull,
    );
  });

  test('사진 형식을 앞부분 서명으로 알아낸다', () {
    expect(mediaTypeOf(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'image/png');
    expect(mediaTypeOf(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits)), 'image/webp');
    expect(mediaTypeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
  });

  test('하루의 경계는 한국 자정', () {
    // 한국 시각 10월 29일 오전 8시 59분 = UTC 10월 28일 23시 59분
    expect(seoulToday(DateTime.utc(2026, 10, 28, 23, 59)), DateTime(2026, 10, 29));
    // 한국 시각 10월 28일 오후 11시 59분
    expect(seoulToday(DateTime.utc(2026, 10, 28, 14, 59)), DateTime(2026, 10, 28));
    expect(seoulMidnightUtc(DateTime(2026, 10, 28)), DateTime.utc(2026, 10, 27, 15));
  });
}
