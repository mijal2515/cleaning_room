# 방긋 (Banggeut)

원룸 1인 가구를 위한 AI 청소 코치 앱. 방 사진을 처음 한 번 찍으면 AI가 방 프로필(자주 어질러지는 구역과 할 일)을 만들고,
그 뒤로는 사진 없이 매일 5~10분짜리 할 일 3개를 골라 준다. 할 일을 끝내면 코인을 받아 미니어처 방을 꾸미고 캐릭터를 키운다.

설계 문서: https://claude.ai/artifact/BqVfuy6RwJ7AYGFyavxfkH

## 폴더

| 폴더 | 내용 |
| --- | --- |
| `app/` | Flutter 앱 (Android). Riverpod, go_router, supabase_flutter |
| `supabase/migrations/` | 테이블, 보안 규칙(RLS), 코인 지급·구매 함수 |
| `supabase/functions/` | Edge Functions. `analyze-room`(방 사진 분석), `complete-session`(청소 완료와 코인) |
| `supabase/functions/_shared/room-analysis.ts` | Claude에게 보내는 프롬프트와 응답 형식. 앱 서버와 품질 테스트 도구가 같이 쓴다 |
| `supabase/tests/` | DB 테스트 (보안 규칙, 코인 계산, 하루 사용량) |
| `tools/ai-eval/` | AI 품질 테스트 도구. 방 사진 여러 장을 분석해서 직접 채점하는 보고서를 만든다 |

## 처음 설정

필요한 것: [Supabase 계정](https://supabase.com), [Anthropic API 키](https://console.anthropic.com), Flutter 3.47 이상, Node 22 이상.

1. Supabase에서 새 프로젝트를 만든다 (지역은 Seoul 권장).
2. 대시보드의 Authentication → Sign In / Providers에서 **Anonymous sign-ins**를 켠다. 앱은 가입 없이 익명으로 시작한다.
3. 터미널에서:

   ```
   npx supabase login
   npx supabase link --project-ref <프로젝트 ID>
   npx supabase db push --include-seed        # 테이블과 시작 가구 10개
   npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   npx supabase functions deploy analyze-room complete-session
   ```

4. 앱 설정: `app/env.example.json`을 `app/env.json`으로 복사하고, 대시보드의 Project Settings → API Keys에서
   프로젝트 주소와 **publishable** 키를 채운다. (secret 키는 절대 앱에 넣지 않는다.)
5. 앱 실행:

   ```
   cd app
   flutter run --dart-define-from-file=env.json
   ```

## 테스트

```
npm install
npm run test:db                      # DB 테스트. 로컬 PostgreSQL(16 이상)이 필요하다
cd app && flutter analyze && flutter test
```

## AI 품질 테스트 (출시 전 관문)

실제 원룸 사진 30장 정도를 한 폴더에 모아서 돌린다. 사진은 Anthropic API로만 보내고 다른 곳에는 올리지 않는다.

```
npm install
ANTHROPIC_API_KEY=sk-ant-... npm run eval -- ./사진폴더
ANTHROPIC_API_KEY=sk-ant-... npm run eval -- ./사진폴더 --model claude-haiku-5-5 --model claude-sonnet-5-5   # 두 모델 비교
```

`tools/ai-eval/out/<시각>/report.html`을 열어 사진마다 "바로 따라 할 만함 / 애매함 / 틀림"을 고른다.
"바로 따라 할 만함"이 80% 이상이면 통과. 미달이면 프롬프트(`room-analysis.ts`)를 고치고 `PROMPT_VERSION`을 올린 뒤 다시 돌린다.

## 운영 설정

`app_config` 테이블에서 앱을 다시 배포하지 않고 바꿀 수 있다.

| 키 | 기본값 | 뜻 |
| --- | --- | --- |
| `ai_model` | `claude-haiku-5-5` | 분석에 쓰는 모델 |
| `free_daily_analyses` | 2 | 하루 사진 분석 횟수 (방 등록, 주간 점검, "오늘 너무 지저분해") |
| `free_daily_compares` | 3 | 하루 비포·애프터 비교 횟수 |
| `daily_coin_cap` | 100 | 하루 최대 코인 |
| `coins_per_task` 등 | 10 | 할 일 1개, 전부 완료, 사진, 3일 연속 보너스 |
