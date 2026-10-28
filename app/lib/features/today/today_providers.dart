import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'today_tasks.dart';

/// 사진 분석으로 받은 오늘 할 일. 그날만 쓰고, 다음 날에는 방 프로필에서 다시 고른다.
class AiPlan {
  const AiPlan({required this.day, required this.tasks, required this.encouragement});

  final DateTime day;
  final List<TodayTask> tasks;
  final String encouragement;
}

class AiPlanNotifier extends Notifier<AiPlan?> {
  @override
  AiPlan? build() => null;

  void set(RoomAnalysis analysis) =>
      state = AiPlan(day: seoulToday(), tasks: analysis.todayTasks, encouragement: analysis.encouragement);
}

final aiPlanProvider = NotifierProvider<AiPlanNotifier, AiPlan?>(AiPlanNotifier.new);

class TodayPlan {
  const TodayPlan({required this.tasks, required this.fromAi, this.message});

  final List<TodayTask> tasks;
  final bool fromAi;
  final String? message;
}

final todayPlanProvider = FutureProvider<TodayPlan>((ref) async {
  final hotspots = await ref.watch(hotspotsProvider.future);
  final ai = ref.watch(aiPlanProvider);
  final today = seoulToday();
  if (ai != null && ai.day == today) {
    final idByName = {for (final h in hotspots) h.name: h.id};
    return TodayPlan(
      tasks: [for (final t in ai.tasks) t.withHotspot(idByName[t.area])],
      fromAi: true,
      message: ai.encouragement,
    );
  }
  return TodayPlan(tasks: pickTodayTasks(hotspots, today), fromAi: false);
});

final doneTodayProvider = FutureProvider<bool>(
  (ref) => ref.watch(roomRepositoryProvider).doneToday(),
);
