-- 로컬 Postgres에서 RLS와 코인 규칙을 검사한다. 실패하면 예외로 멈춘다.
\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');

do $$ begin
  assert (select count(*) from public.profiles) = 2, '가입하면 프로필이 자동으로 생겨야 한다';
end $$;

-- 사용자 A로 접속
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false) \gset

do $$ begin
  assert (select count(*) from public.profiles) = 1, 'A는 자기 프로필만 보여야 한다';
end $$;

-- 코인 직접 수정은 막혀야 한다
do $$ begin
  begin
    update public.profiles set coins = 9999;
    raise exception 'coins update should have failed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 이름은 바꿀 수 있다
update public.profiles set display_name = '재원';

-- 청소 기록을 직접 쓸 수 없다
do $$ begin
  begin
    insert into public.sessions (user_id, kind) values ('00000000-0000-0000-0000-00000000000a', 'daily');
    raise exception 'sessions insert should have failed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 서버 전용 함수는 부를 수 없다
do $$ begin
  begin
    perform public.complete_session('00000000-0000-0000-0000-00000000000a', 'daily', '[]', 3, 3, false);
    raise exception 'complete_session should be service-only';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 방 프로필은 자기 것만 쓸 수 있다
insert into public.room_hotspots (user_id, name, tasks) values
  ('00000000-0000-0000-0000-00000000000a', '책상 위', '[{"title":"컵 치우기","minutes":2}]');
do $$ begin
  begin
    insert into public.room_hotspots (user_id, name) values ('00000000-0000-0000-0000-00000000000b', '남의 방');
    raise exception 'insert for another user should have failed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 코인이 없으면 살 수 없다
do $$ begin
  begin
    perform public.buy_item('plant_cactus');
    raise exception 'buy without coins should have failed';
  exception when raise_exception then null;
  end;
end $$;

reset role;

-- 서버(service_role)로 청소 완료 처리
set role service_role;

do $$
declare r jsonb;
begin
  -- 3개 중 3개 완료 + 애프터 사진: 10*3 + 10 + 10 = 50
  r := public.complete_session('00000000-0000-0000-0000-00000000000a', 'daily', '[]', 3, 3, true);
  assert (r->>'coins_awarded')::int = 50, format('첫 청소는 50코인이어야 한다: %s', r);
  assert (r->>'streak_days')::int = 1, '첫 청소의 연속 일수는 1';

  -- 사진 없이 2개 완료: 20코인
  r := public.complete_session('00000000-0000-0000-0000-00000000000a', 'daily', '[]', 3, 2, false);
  assert (r->>'coins_awarded')::int = 20, format('사진 없이 2개는 20코인: %s', r);

  -- 하루 상한 100: 이미 70, 이번 50 중 30만 받는다
  r := public.complete_session('00000000-0000-0000-0000-00000000000a', 'daily', '[]', 3, 3, true);
  assert (r->>'coins_awarded')::int = 30, format('하루 상한 때문에 30코인: %s', r);
  assert (r->>'coins')::int = 100, '총 100코인';
end $$;

-- 어제 청소한 것으로 바꾸면 연속 일수가 이어진다
update public.profiles set last_cleaned_at = now() - interval '1 day', streak_days = 2
 where id = '00000000-0000-0000-0000-00000000000a';
update public.sessions set created_at = now() - interval '1 day';
do $$
declare r jsonb;
begin
  r := public.complete_session('00000000-0000-0000-0000-00000000000a', 'daily', '[]', 1, 1, false);
  assert (r->>'streak_days')::int = 3, format('연속 3일: %s', r);
  -- 10 + 모두 완료 10 + 3일 연속 20 = 40
  assert (r->>'coins_awarded')::int = 40, format('3일 연속 보너스 포함 40코인: %s', r);
end $$;

-- AI 무료 한도 (분석 2회, 비교 3회)
do $$ begin
  assert public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'analysis') = true;
  assert public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'analysis') = true;
  assert public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'analysis') = false, '3번째 분석은 한도 초과';
  assert public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'compare') = true, '비교 한도는 따로 센다';
end $$;

reset role;

-- 다시 사용자 A: 구매와 배치
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false) \gset

do $$
declare left_coins int; placed jsonb;
begin
  left_coins := public.buy_item('plant_cactus');
  assert left_coins = 120, format('140 - 20 = 120: %s', left_coins);

  begin
    perform public.buy_item('plant_cactus');
    raise exception 'double buy should fail';
  exception when unique_violation then null;
  end;

  placed := public.place_item('plant', 'plant_cactus');
  assert placed->>'plant' = 'plant_cactus';

  begin
    perform public.place_item('rug', 'plant_cactus');
    raise exception 'wrong slot should fail';
  exception when raise_exception then null;
  end;

  placed := public.place_item('plant', null);
  assert not (placed ? 'plant'), '슬롯 비우기';
end $$;

-- B의 데이터는 보이지 않는다
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false) \gset
do $$ begin
  assert (select count(*) from public.sessions) = 0, 'B는 A의 기록을 볼 수 없다';
  assert (select count(*) from public.room_hotspots) = 0, 'B는 A의 방 프로필을 볼 수 없다';
  assert (select count(*) from public.inventory) = 0, 'B는 A의 아이템을 볼 수 없다';
  assert (select count(*) from public.items) = 10, '상점 아이템은 누구나 본다';
end $$;

reset role;
\echo 'ALL TESTS PASSED'
