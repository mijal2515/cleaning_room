/// 하루의 경계는 서버와 같이 한국 자정이다. 한국은 서머타임이 없어 +9시간으로 충분하다.
DateTime seoulToday([DateTime? now]) {
  final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return DateTime(kst.year, kst.month, kst.day);
}

/// 한국 날짜의 자정을 UTC 시각으로 바꾼다. 서버 시각과 비교할 때 쓴다.
DateTime seoulMidnightUtc(DateTime seoulDay) =>
    DateTime.utc(seoulDay.year, seoulDay.month, seoulDay.day).subtract(const Duration(hours: 9));
