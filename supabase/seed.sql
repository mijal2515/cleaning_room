-- 상점 시작 아이템. 이미지는 앱 에셋(assets/room/items/<id>.png)에 둔다.
insert into public.items (id, slot, price, name) values
  ('rug_round_beige',   'rug',    30, '동그란 베이지 러그'),
  ('rug_stripe_green',  'rug',    50, '초록 줄무늬 러그'),
  ('plant_monstera',    'plant',  40, '몬스테라 화분'),
  ('plant_cactus',      'plant',  20, '작은 선인장'),
  ('lamp_mushroom',     'lamp',   60, '버섯 무드등'),
  ('lamp_floor_wood',   'lamp',   80, '원목 스탠드'),
  ('bed_cover_cloud',   'bed',    70, '구름 이불'),
  ('desk_white',        'desk',  100, '하얀 책상'),
  ('wall_poster_cat',   'wall',   25, '고양이 포스터'),
  ('window_curtain_sky','window', 45, '하늘색 커튼')
on conflict (id) do nothing;
