-- 초기 스키마: 프로필, 방 프로필, 반복 집안일, 청소 기록, 아이템, 날씨 캐시, 설정
-- 하루의 경계는 한국 시간(Asia/Seoul) 기준으로 계산한다.

-- ───────────────────────── 테이블 ─────────────────────────

create table public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  display_name     text,
  coins            integer not null default 0 check (coins >= 0),
  streak_days      integer not null default 0 check (streak_days >= 0),
  last_cleaned_at  timestamptz,
  character_stage  smallint not null default 1 check (character_stage between 1 and 3),
  character_xp     integer not null default 0 check (character_xp >= 0),
  placed_items     jsonb not null default '{}'::jsonb,  -- 슬롯 id → 아이템 id
  grid_nx          smallint,                            -- 기상청 격자 X
  grid_ny          smallint,                            -- 기상청 격자 Y
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 방 프로필: 자주 어질러지는 구역과 구역별 할 일
create table public.room_hotspots (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  zone           text not null default 'room' check (zone in ('room', 'fridge', 'bathroom', 'kitchen')),
  name           text not null check (char_length(name) between 1 and 40),
  typical_items  text[] not null default '{}',
  tasks          jsonb not null default '[]'::jsonb,  -- [{ "title": text, "minutes": int }]
  source         text not null default 'user' check (source in ('ai', 'user')),
  sort_order     smallint not null default 0,
  last_done_at   timestamptz,
  created_at     timestamptz not null default now()
);
create index room_hotspots_user_idx on public.room_hotspots (user_id, zone);

-- 반복 집안일 (청소기, 이불 빨래, 쓰레기 배출 등)
create table public.chores (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 40),
  category      text not null default 'cleaning' check (category in ('cleaning', 'laundry', 'trash', 'bathroom', 'kitchen', 'other')),
  interval_days smallint check (interval_days between 1 and 90),
  weekdays      smallint[] check (weekdays <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[]),  -- 0 = 일요일
  weather_rule  text not null default 'none' check (weather_rule in ('none', 'no_rain', 'dry_sunny')),
  last_done_on  date,
  next_due_on   date,
  enabled       boolean not null default true,
  created_at    timestamptz not null default now(),
  check (interval_days is not null or weekdays is not null)
);
create index chores_user_idx on public.chores (user_id);

-- 청소 기록. 앱은 읽기만 하고, 쓰기는 Edge Functions(service_role)가 한다.
create table public.sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  kind             text not null check (kind in ('register', 'weekly', 'now', 'daily')),
  zone             text not null default 'room',
  tasks            jsonb not null default '[]'::jsonb,
  messiness        smallint check (messiness between 0 and 100),
  tasks_total      smallint not null default 0,
  tasks_completed  smallint not null default 0,
  after_photo      boolean not null default false,
  coins_awarded    integer not null default 0,
  created_at       timestamptz not null default now(),
  completed_at     timestamptz
);
create index sessions_user_created_idx on public.sessions (user_id, created_at desc);

-- 하루 AI 사용량 (무료 한도 계산용). kind: analysis = 방 분석, compare = 비포·애프터 비교
create table public.ai_usage (
  user_id  uuid not null references auth.users (id) on delete cascade,
  day      date not null,
  kind     text not null check (kind in ('analysis', 'compare')),
  count    integer not null default 0,
  primary key (user_id, day, kind)
);

-- 아이템 카탈로그. 가격은 서버에서 검증해야 하므로 DB에 둔다. 이미지는 앱 에셋.
create table public.items (
  id      text primary key,
  slot    text not null,
  price   integer not null check (price >= 0),
  name    text not null,
  active  boolean not null default true
);

create table public.inventory (
  user_id      uuid not null references auth.users (id) on delete cascade,
  item_id      text not null references public.items (id),
  acquired_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- 기상청 단기예보를 격자·날짜별로 저장 (사용자 수가 아니라 격자 수만큼 호출)
create table public.weather_cache (
  nx             smallint not null,
  ny             smallint not null,
  forecast_date  date not null,
  pop_max        smallint,       -- 하루 최대 강수확률 (%)
  reh_min        smallint,       -- 낮 시간 최저 습도 (%)
  tmp_max        numeric(4, 1),  -- 최고 기온 (°C)
  sky            smallint,       -- 하늘상태 코드 (1 맑음, 3 구름많음, 4 흐림)
  laundry_score  smallint check (laundry_score between 0 and 100),
  fetched_at     timestamptz not null default now(),
  primary key (nx, ny, forecast_date)
);

-- 앱 업데이트 없이 바꾸는 설정 (AI 모델, 무료 한도, 코인 규칙)
create table public.app_config (
  key    text primary key,
  value  jsonb not null
);

insert into public.app_config (key, value) values
  ('ai_model', '"claude-haiku-5-5"'),
  ('prompt_version', '"room-v1"'),
  ('free_daily_analyses', '2'),
  ('free_daily_compares', '3'),
  ('daily_coin_cap', '100'),
  ('coins_per_task', '10'),
  ('coins_all_done_bonus', '10'),
  ('coins_photo_bonus', '10'),
  ('coins_streak_bonus', '20');

-- ───────────────────────── 새 사용자 프로필 자동 생성 ─────────────────────────

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────── 행 단위 보안 (RLS) ─────────────────────────

alter table public.profiles      enable row level security;
alter table public.room_hotspots enable row level security;
alter table public.chores        enable row level security;
alter table public.sessions      enable row level security;
alter table public.ai_usage      enable row level security;
alter table public.items         enable row level security;
alter table public.inventory     enable row level security;
alter table public.weather_cache enable row level security;
alter table public.app_config    enable row level security;

-- 프로필: 자기 것만 읽는다. 코인·경험치는 직접 못 바꾸고, 이름과 위치 격자만 바꾼다.
create policy "profiles: read own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles: update own" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
revoke update on public.profiles from authenticated;
grant update (display_name, grid_nx, grid_ny) on public.profiles to authenticated;

-- 방 프로필과 반복 집안일: 사용자가 자유롭게 고친다.
create policy "room_hotspots: own" on public.room_hotspots
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "chores: own" on public.chores
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- 청소 기록과 보유 아이템: 읽기만.
create policy "sessions: read own" on public.sessions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "inventory: read own" on public.inventory
  for select to authenticated using ((select auth.uid()) = user_id);

-- 공용 데이터: 로그인한 사용자 누구나 읽기.
create policy "items: read" on public.items
  for select to authenticated using (active);
create policy "weather_cache: read" on public.weather_cache
  for select to authenticated using (true);
create policy "app_config: read" on public.app_config
  for select to authenticated using (true);

-- ai_usage에는 정책이 없으므로 앱에서 접근할 수 없다 (service_role만 사용).

-- ───────────────────────── 함수 ─────────────────────────

create function public.app_config_int(p_key text, p_default integer)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce((select (value #>> '{}')::integer from public.app_config where key = p_key), p_default);
$$;

-- 아이템 구매: 코인 차감과 지급을 한 트랜잭션으로 처리한다.
create function public.buy_item(p_item_id text)
returns integer  -- 남은 코인
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user  uuid := auth.uid();
  v_price integer;
  v_coins integer;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select price into v_price from public.items where id = p_item_id and active;
  if v_price is null then
    raise exception 'unknown item' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.inventory where user_id = v_user and item_id = p_item_id) then
    raise exception 'already owned' using errcode = '23505';
  end if;

  select coins into v_coins from public.profiles where id = v_user for update;
  if v_coins < v_price then
    raise exception 'not enough coins' using errcode = 'P0001';
  end if;

  update public.profiles
     set coins = coins - v_price, updated_at = now()
   where id = v_user
  returning coins into v_coins;

  insert into public.inventory (user_id, item_id) values (v_user, p_item_id);
  return v_coins;
end;
$$;

-- 가구 배치: 가진 아이템만, 맞는 슬롯에만 놓는다. p_item_id가 null이면 슬롯을 비운다.
create function public.place_item(p_slot text, p_item_id text)
returns jsonb  -- 바뀐 placed_items
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user   uuid := auth.uid();
  v_placed jsonb;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_item_id is not null and not exists (
    select 1
      from public.inventory inv
      join public.items it on it.id = inv.item_id
     where inv.user_id = v_user and inv.item_id = p_item_id and it.slot = p_slot
  ) then
    raise exception 'item not owned or wrong slot' using errcode = 'P0001';
  end if;

  update public.profiles
     set placed_items = case
           when p_item_id is null then placed_items - p_slot
           else jsonb_set(placed_items, array[p_slot], to_jsonb(p_item_id))
         end,
         updated_at = now()
   where id = v_user
  returning placed_items into v_placed;

  return v_placed;
end;
$$;

-- 하루 AI 사용 한도: 한도 안이면 1 늘리고 true, 넘으면 false.
create function public.consume_ai_quota(p_user_id uuid, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day   date := (now() at time zone 'Asia/Seoul')::date;
  v_limit integer := case p_kind
    when 'compare' then public.app_config_int('free_daily_compares', 3)
    else public.app_config_int('free_daily_analyses', 2)
  end;
  v_count integer;
begin
  insert into public.ai_usage (user_id, day, kind, count)
  values (p_user_id, v_day, p_kind, 1)
  on conflict (user_id, day, kind) do update
     set count = public.ai_usage.count + 1
   where public.ai_usage.count < v_limit
  returning count into v_count;

  return v_count is not null;
end;
$$;

-- 청소 완료 처리: 기록 저장, 코인·연속 일수·경험치 갱신을 한 번에 한다.
-- 코인은 AI 점수가 아니라 완료한 할 일 수, 사진 여부, 연속 일수로 준다.
create function public.complete_session(
  p_user_id         uuid,
  p_kind            text,
  p_tasks           jsonb,
  p_tasks_total     integer,
  p_tasks_completed integer,
  p_after_photo     boolean,
  p_zone            text default 'room'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today       date := (now() at time zone 'Asia/Seoul')::date;
  v_last_day    date;
  v_streak      integer;
  v_new_streak  integer;
  v_earned_today integer;
  v_cap         integer := public.app_config_int('daily_coin_cap', 100);
  v_coins       integer := 0;
  v_completed   integer := greatest(0, least(p_tasks_completed, p_tasks_total));
  v_profile     public.profiles;
  v_session_id  uuid;
begin
  if p_tasks_total < 0 or p_tasks_total > 10 then
    raise exception 'invalid task count' using errcode = '22023';
  end if;

  select * into v_profile from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002';
  end if;

  v_last_day := (v_profile.last_cleaned_at at time zone 'Asia/Seoul')::date;
  v_streak := v_profile.streak_days;

  if v_completed > 0 then
    v_coins := v_completed * public.app_config_int('coins_per_task', 10);
    if v_completed = p_tasks_total then
      v_coins := v_coins + public.app_config_int('coins_all_done_bonus', 10);
    end if;
    if p_after_photo then
      v_coins := v_coins + public.app_config_int('coins_photo_bonus', 10);
    end if;

    v_new_streak := case
      when v_last_day = v_today then v_streak
      when v_last_day = v_today - 1 then v_streak + 1
      else 1
    end;
    if v_new_streak <> v_streak and v_new_streak % 3 = 0 then
      v_coins := v_coins + public.app_config_int('coins_streak_bonus', 20);
    end if;
  else
    v_new_streak := v_streak;
  end if;

  -- 하루 코인 상한
  select coalesce(sum(coins_awarded), 0) into v_earned_today
    from public.sessions
   where user_id = p_user_id
     and (created_at at time zone 'Asia/Seoul')::date = v_today;
  v_coins := greatest(0, least(v_coins, v_cap - v_earned_today));

  insert into public.sessions (user_id, kind, zone, tasks, tasks_total, tasks_completed, after_photo, coins_awarded, completed_at)
  values (p_user_id, p_kind, p_zone, coalesce(p_tasks, '[]'::jsonb), p_tasks_total, v_completed, p_after_photo, v_coins, now())
  returning id into v_session_id;

  update public.profiles
     set coins           = coins + v_coins,
         streak_days     = v_new_streak,
         last_cleaned_at = case when v_completed > 0 then now() else last_cleaned_at end,
         character_xp    = character_xp + v_completed,
         character_stage = case
           when character_xp + v_completed >= 150 then 3
           when character_xp + v_completed >= 40 then 2
           else 1
         end,
         updated_at      = now()
   where id = p_user_id
  returning * into v_profile;

  return jsonb_build_object(
    'session_id', v_session_id,
    'coins_awarded', v_coins,
    'coins', v_profile.coins,
    'streak_days', v_profile.streak_days,
    'character_stage', v_profile.character_stage
  );
end;
$$;

-- 앱(anon, authenticated)이 부를 수 있는 함수와 서버 전용 함수를 나눈다.
revoke execute on function public.buy_item(text)                                          from public, anon;
revoke execute on function public.place_item(text, text)                                  from public, anon;
revoke execute on function public.consume_ai_quota(uuid, text)                                  from public, anon, authenticated;
revoke execute on function public.complete_session(uuid, text, jsonb, integer, integer, boolean, text) from public, anon, authenticated;
revoke execute on function public.handle_new_user()                                       from public, anon, authenticated;
grant  execute on function public.buy_item(text)                                          to authenticated;
grant  execute on function public.place_item(text, text)                                  to authenticated;
grant  execute on function public.consume_ai_quota(uuid, text)                                  to service_role;
grant  execute on function public.complete_session(uuid, text, jsonb, integer, integer, boolean, text) to service_role;
