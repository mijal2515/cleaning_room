# 청소 코치 (cleaning_room)

원룸 1인 가구를 위한 AI 청소 코치 Android 앱. 사용자(재원)와는 한국어로 대화한다.
설계 문서: https://claude.ai/artifact/BqVfuy6RwJ7AYGFyavxfkH (기능 범위, 아키텍처, 비용, 12주 일정)

## 정해진 것 (바꾸기 전에 재원에게 물어볼 것)

- Flutter(Android 먼저) + Supabase. Firebase는 쓰지 않는다.
- 사진은 처음 방 등록 때만 필수. AI가 방 프로필(`room_hotspots`: 구역별 할 일 목록)을 만들고,
  매일의 할 일 3개(합계 5~10분)는 앱이 사진과 AI 없이 프로필에서 고른다(`app/lib/features/today/today_tasks.dart`).
  주간 점검, "오늘 너무 지저분해", 애프터 사진은 선택이다. 사진은 서버에 저장하지 않는다.
- 보상: 코인으로 미니어처 방을 꾸미고, 다마고치·썸원 감성 캐릭터가 자란다. 코인은 AI 점수가 아니라 완료한 할 일 수로 준다.
  코인 계산은 서버(`complete_session` DB 함수)에서만 한다. 앱이 코인 컬럼을 직접 바꾸지 못하게 RLS와 컬럼 권한으로 막아 두었다.
- AI는 Claude Haiku 5.5(`claude-haiku-5-5`). 모델 이름과 무료 한도는 `app_config` 테이블에 있어 앱 배포 없이 바꾼다.
- 캐릭터 말투: 반말, 짧고 다정하게, 사용자를 탓하지 않음, 이모지 없음.
- 단계: MVP = 오늘 할 일 + 날씨 기반 집안일 일정 + 캐릭터·방 꾸미기 + 비포·애프터.
  2차 = 서랍 정리 플래너, 꿀팁·용품 추천(쿠팡 파트너스, 대가성 문구 필수). 3차 = 냉장고·화장실·주방, 구독, 앱 잠금, 룸메이트.

## 구조와 명령

- `app/` Flutter 앱. Riverpod 3(Notifier/FutureProvider, StateProvider는 쓰지 않음), go_router, supabase_flutter(`publishableKey`).
  - 실행: `cd app && cp env.example.json env.json` 후 값 채우고 `flutter run --dart-define-from-file=env.json`
  - 확인: `flutter analyze && flutter test`
- `supabase/migrations/` 스키마, RLS, RPC(`buy_item`, `place_item`, `consume_ai_quota`, `complete_session`).
  - DB 테스트: `npm install && npm run test:db` (로컬 PostgreSQL 16 이상 필요, Docker 없이 돈다)
- `supabase/functions/` Edge Functions `analyze-room`, `complete-session`. 프롬프트와 응답 스키마는 `_shared/room-analysis.ts`.
  - 타입 검사: 각 함수 폴더에서 `npx -y deno check index.ts`
  - 프롬프트를 고치면 `PROMPT_VERSION`을 올린다.
- `tools/ai-eval/` AI 품질 테스트: `ANTHROPIC_API_KEY=... npm run eval -- <사진 폴더>` → `tools/ai-eval/out/<시각>/report.html`에서 직접 채점.
  출시 관문은 "바로 따라 할 만함" 80% 이상.
- 처음 배포 순서는 `README.md`에 있다.

## 지금 상태 (2026-10-28)

1~2주차 기초 완료: DB와 보상 규칙, 두 Edge Function, 품질 테스트 도구, 앱 뼈대(익명 로그인 → 방 등록 → 오늘 할 일 3개 → 완료하면 코인).
`내 방`, `나` 화면은 자리만 있다.

아직 확인하지 못한 것:
- 실제 Claude API 호출 (API 키가 없었음)
- Android 기기·에뮬레이터에서 실행 (Android SDK가 없는 환경에서 만듦)
- 실제 Supabase 프로젝트에 배포

다음 할 일 (설계 문서 일정 기준):
1. Supabase 프로젝트 만들고 배포, 앱을 기기에서 실행해 보기
2. 원룸 사진 30장으로 AI 품질 테스트, 필요하면 프롬프트 수정
3. 집안일 스케줄 + 기상청 단기예보(`chores`, `weather_cache` 테이블은 이미 있음)
4. 가구 상점과 방 꾸미기 화면, 캐릭터(Rive), 비포·애프터 슬라이더
