-- =====================================================================
--  Phòng Trưng Bày 3D — cơ sở dữ liệu Supabase
--  Chạy toàn bộ file này một lần trong Supabase → SQL Editor → Run.
--  Chạy lại nhiều lần cũng không sao (an toàn khi cập nhật).
-- =====================================================================
create extension if not exists pgcrypto;

-- ---------- Bảng ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_.]{3,24}$'),
  display_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.galleries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null default 'Phòng trưng bày',
  slug text unique not null,
  visibility text not null default 'link' check (visibility in ('link', 'private')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.gallery_members (
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'editor' check (role in ('owner', 'editor')),
  added_at timestamptz not null default now(),
  primary key (gallery_id, user_id)
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  name text not null default 'Gian mới',
  theme text not null default 'classic',
  stars boolean not null default false,
  sort int not null default 0,
  layout jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  room_id uuid not null references public.rooms(id) on delete cascade,
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  slot text not null,
  kind text not null check (kind in ('image', 'video', 'model')),
  path text not null,
  title text not null default '',
  artist text not null default '',
  year text not null default '',
  description text not null default '',
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  primary key (room_id, slot)
);

-- Cập nhật cho bản có đèn riêng từng tác phẩm (chạy lại cả file là đủ)
alter table public.rooms add column if not exists lights jsonb not null default '{}'::jsonb;

create index if not exists items_gallery_idx on public.items (gallery_id);
create index if not exists rooms_gallery_idx on public.rooms (gallery_id);
create index if not exists members_user_idx on public.gallery_members (user_id);

-- ---------- Hàm kiểm tra quyền ----------
create or replace function public.is_member(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from gallery_members where gallery_id = g and user_id = auth.uid());
$$;

create or replace function public.is_owner(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from galleries where id = g and owner_id = auth.uid());
$$;

-- ---------- Tài khoản mới → hồ sơ ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    lower(new.raw_user_meta_data ->> 'username'),
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), new.raw_user_meta_data ->> 'username')
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Tạo phòng trưng bày (chủ phòng + gian đầu tiên) ----------
create or replace function public.create_gallery(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare
  g_id uuid;
  s text;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  s := substr(md5(gen_random_uuid()::text), 1, 10);
  insert into galleries (owner_id, name, slug)
  values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'Phòng trưng bày'), s)
  returning id into g_id;
  insert into gallery_members (gallery_id, user_id, role) values (g_id, auth.uid(), 'owner');
  insert into rooms (gallery_id, name, theme, sort) values (g_id, 'Gian 1', 'classic', 0);
  return s;
end $$;

-- ---------- Đọc phòng trưng bày qua link chia sẻ (khách không cần tài khoản) ----------
create or replace function public.get_shared_gallery(p_slug text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  g galleries;
  r text;
begin
  select * into g from galleries where slug = p_slug;
  if not found then
    return null;
  end if;
  select role into r from gallery_members where gallery_id = g.id and user_id = auth.uid();
  if r is null and g.visibility = 'private' then
    return jsonb_build_object('private', true, 'name', g.name);
  end if;
  return jsonb_build_object(
    'gallery', jsonb_build_object('id', g.id, 'name', g.name, 'slug', g.slug, 'visibility', g.visibility,
                                  'owner_id', g.owner_id, 'settings', g.settings),
    'owner', (select jsonb_build_object('username', p.username, 'display_name', p.display_name)
              from profiles p where p.id = g.owner_id),
    'role', coalesce(r, 'viewer'),
    'rooms', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort, x.created_at)
                       from rooms x where x.gallery_id = g.id), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(to_jsonb(i)) from items i where i.gallery_id = g.id), '[]'::jsonb)
  );
end $$;

grant execute on function public.get_shared_gallery(text) to anon, authenticated;
grant execute on function public.create_gallery(text) to authenticated;

-- ---------- Bảo mật theo dòng (RLS) ----------
alter table public.profiles enable row level security;
alter table public.galleries enable row level security;
alter table public.gallery_members enable row level security;
alter table public.rooms enable row level security;
alter table public.items enable row level security;

drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles
  for select to authenticated using (true);
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "gallery read" on public.galleries;
create policy "gallery read" on public.galleries
  for select to authenticated using (owner_id = auth.uid() or public.is_member(id));
drop policy if exists "gallery owner update" on public.galleries;
create policy "gallery owner update" on public.galleries
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "gallery owner delete" on public.galleries;
create policy "gallery owner delete" on public.galleries
  for delete to authenticated using (owner_id = auth.uid());

drop policy if exists "members read" on public.gallery_members;
create policy "members read" on public.gallery_members
  for select to authenticated using (public.is_member(gallery_id));
drop policy if exists "owner invites" on public.gallery_members;
create policy "owner invites" on public.gallery_members
  for insert to authenticated with check (public.is_owner(gallery_id) and role = 'editor');
drop policy if exists "owner removes or member leaves" on public.gallery_members;
create policy "owner removes or member leaves" on public.gallery_members
  for delete to authenticated using (role <> 'owner' and (public.is_owner(gallery_id) or user_id = auth.uid()));

drop policy if exists "members manage rooms" on public.rooms;
create policy "members manage rooms" on public.rooms
  for all to authenticated using (public.is_member(gallery_id)) with check (public.is_member(gallery_id));

drop policy if exists "members manage items" on public.items;
create policy "members manage items" on public.items
  for all to authenticated using (public.is_member(gallery_id))
  with check (
    public.is_member(gallery_id)
    and exists (select 1 from public.rooms r where r.id = items.room_id and r.gallery_id = items.gallery_id)
  );

-- ---------- Cập nhật trực tiếp (realtime) cho thành viên ----------
alter table public.items replica identity full;
alter table public.rooms replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.items;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null;
end $$;

-- ---------- Kho ảnh / video / mô hình 3D ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 52428800)
on conflict (id) do nothing;

drop policy if exists "gallery media insert" on storage.objects;
create policy "gallery media insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and public.is_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "gallery media select" on storage.objects;
create policy "gallery media select" on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and public.is_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "gallery media delete" on storage.objects;
create policy "gallery media delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and public.is_member(((storage.foldername(name))[1])::uuid));

-- =====================================================================
--  Ví xu, thả tim / đánh giá, ủng hộ (chạy lại cả file vẫn an toàn)
-- =====================================================================
create table if not exists public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance int not null default 2000 check (balance >= 0),
  updated_at timestamptz not null default now()
);
alter table public.wallets enable row level security;
drop policy if exists "wallet self read" on public.wallets;
create policy "wallet self read" on public.wallets for select to authenticated using (user_id = auth.uid());

create table if not exists public.feedback (
  id bigserial primary key,
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  slot text not null default '',          -- '' = cả gian
  rater text not null,                    -- id tài khoản, hoặc 'anon:<mã trình duyệt>'
  kind text not null check (kind in ('heart', 'clap', 'wow', 'haha', 'fire', 'rate')),
  stars int check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  unique (room_id, slot, rater, kind)
);
create index if not exists feedback_gallery_idx on public.feedback (gallery_id);
alter table public.feedback enable row level security;  -- chỉ đọc/ghi qua các hàm bên dưới

create table if not exists public.donations (
  id bigserial primary key,
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  room_id uuid references public.rooms(id) on delete set null,
  slot text not null default '',
  from_user uuid references public.profiles(id) on delete set null,
  to_user uuid references public.profiles(id) on delete set null,
  amount int not null check (amount > 0),
  message text not null default '' check (length(message) <= 200),
  created_at timestamptz not null default now()
);
create index if not exists donations_gallery_idx on public.donations (gallery_id);
alter table public.donations enable row level security;
drop policy if exists "donations involved read" on public.donations;
create policy "donations involved read" on public.donations for select to authenticated using (from_user = auth.uid() or to_user = auth.uid());

-- khách xem được phòng này không (link công khai, hoặc là thành viên)
create or replace function public.can_view(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from galleries where id = g and (visibility = 'link' or public.is_member(g)));
$$;

create or replace function public.my_wallet() returns int
language plpgsql security definer set search_path = public as $$
declare b int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into wallets (user_id) values (auth.uid()) on conflict do nothing;
  select balance into b from wallets where user_id = auth.uid();
  return b;
end $$;

create or replace function public.spend_xu(p_amount int) returns int
language plpgsql security definer set search_path = public as $$
declare b int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_amount < 0 or p_amount > 100000000 then raise exception 'invalid amount'; end if;
  perform public.my_wallet();
  update wallets set balance = balance - p_amount, updated_at = now()
    where user_id = auth.uid() and balance >= p_amount returning balance into b;
  if not found then raise exception 'not enough xu'; end if;
  return b;
end $$;

create or replace function public.react(p_room uuid, p_slot text, p_kind text, p_rater text) returns boolean
language plpgsql security definer set search_path = public as $$
declare g uuid; who text := coalesce(auth.uid()::text, 'anon:' || left(coalesce(p_rater, ''), 40)); removed int;
begin
  select gallery_id into g from rooms where id = p_room;
  if g is null or not public.can_view(g) then raise exception 'not allowed'; end if;
  if p_kind not in ('heart', 'clap', 'wow', 'haha', 'fire') then raise exception 'bad kind'; end if;
  delete from feedback where room_id = p_room and slot = coalesce(p_slot, '') and rater = who and kind = p_kind;
  get diagnostics removed = row_count;
  if removed > 0 then return false; end if;
  insert into feedback (gallery_id, room_id, slot, rater, kind) values (g, p_room, coalesce(p_slot, ''), who, p_kind);
  return true;
end $$;

create or replace function public.rate(p_room uuid, p_slot text, p_stars int, p_rater text) returns void
language plpgsql security definer set search_path = public as $$
declare g uuid; who text := coalesce(auth.uid()::text, 'anon:' || left(coalesce(p_rater, ''), 40));
begin
  select gallery_id into g from rooms where id = p_room;
  if g is null or not public.can_view(g) then raise exception 'not allowed'; end if;
  if p_stars < 1 or p_stars > 5 then raise exception 'bad stars'; end if;
  insert into feedback (gallery_id, room_id, slot, rater, kind, stars) values (g, p_room, coalesce(p_slot, ''), who, 'rate', p_stars)
  on conflict (room_id, slot, rater, kind) do update set stars = excluded.stars, created_at = now();
end $$;

create or replace function public.donate(p_room uuid, p_slot text, p_amount int, p_message text) returns int
language plpgsql security definer set search_path = public as $$
declare g uuid; owner uuid; b int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_amount < 1 or p_amount > 10000 then raise exception 'invalid amount'; end if;
  select r.gallery_id, gl.owner_id into g, owner from rooms r join galleries gl on gl.id = r.gallery_id where r.id = p_room;
  if g is null or not public.can_view(g) then raise exception 'not allowed'; end if;
  if owner = auth.uid() then raise exception 'cannot donate to yourself'; end if;
  b := public.spend_xu(p_amount);
  insert into wallets (user_id) values (owner) on conflict do nothing;
  update wallets set balance = balance + p_amount, updated_at = now() where user_id = owner;
  insert into donations (gallery_id, room_id, slot, from_user, to_user, amount, message)
    values (g, p_room, coalesce(p_slot, ''), auth.uid(), owner, p_amount, left(coalesce(p_message, ''), 200));
  return b;
end $$;

-- tổng hợp cho cả phòng trưng bày: mỗi tác phẩm / gian một dòng
create or replace function public.get_feedback(p_gallery uuid, p_rater text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare who text := coalesce(auth.uid()::text, 'anon:' || left(coalesce(p_rater, ''), 40));
begin
  if not public.can_view(p_gallery) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(t) from (
      select k.room_id, k.slot,
        (select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) from (select kind, count(*) n from feedback f where f.room_id = k.room_id and f.slot = k.slot and kind <> 'rate' group by kind) c) as counts,
        (select round(avg(stars)::numeric, 2) from feedback f where f.room_id = k.room_id and f.slot = k.slot and kind = 'rate') as avg,
        (select count(*) from feedback f where f.room_id = k.room_id and f.slot = k.slot and kind = 'rate') as votes,
        (select coalesce(sum(amount), 0) from donations d where d.room_id = k.room_id and d.slot = k.slot) as xu,
        (select coalesce(jsonb_agg(kind), '[]'::jsonb) from feedback f where f.room_id = k.room_id and f.slot = k.slot and f.rater = who and kind <> 'rate') as mine,
        (select stars from feedback f where f.room_id = k.room_id and f.slot = k.slot and f.rater = who and kind = 'rate') as my_stars
      from (select distinct room_id, slot from feedback where gallery_id = p_gallery
            union select distinct room_id, slot from donations where gallery_id = p_gallery and room_id is not null) k
    ) t), '[]'::jsonb);
end $$;

grant execute on function public.react(uuid, text, text, text) to anon, authenticated;
grant execute on function public.rate(uuid, text, int, text) to anon, authenticated;
grant execute on function public.get_feedback(uuid, text) to anon, authenticated;
grant execute on function public.my_wallet() to authenticated;
grant execute on function public.spend_xu(int) to authenticated;
grant execute on function public.donate(uuid, text, int, text) to authenticated;
revoke execute on function public.my_wallet() from anon;
revoke execute on function public.spend_xu(int) from anon;
revoke execute on function public.donate(uuid, text, int, text) from anon;

-- =====================================================================
--  Phòng có mật khẩu / thu phí vào cửa (chạy lại cả file vẫn an toàn)
-- =====================================================================
alter table public.galleries drop constraint if exists galleries_visibility_check;
alter table public.galleries add constraint galleries_visibility_check check (visibility in ('link', 'private', 'password', 'paid'));
alter table public.galleries add column if not exists pass_hash text;
alter table public.galleries add column if not exists entry_fee int not null default 0 check (entry_fee between 0 and 100000);

create table if not exists public.gallery_passes (
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (gallery_id, user_id)
);
alter table public.gallery_passes enable row level security;
drop policy if exists "passes self read" on public.gallery_passes;
create policy "passes self read" on public.gallery_passes for select to authenticated using (user_id = auth.uid());

create or replace function public.can_view(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from galleries where id = g and (visibility in ('link', 'password', 'paid') or public.is_member(g)));
$$;

drop function if exists public.get_shared_gallery(text);
create or replace function public.get_shared_gallery(p_slug text, p_password text default null) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  g galleries;
  r text;
begin
  select * into g from galleries where slug = p_slug;
  if not found then return null; end if;
  select role into r from gallery_members where gallery_id = g.id and user_id = auth.uid();
  if r is null then
    if g.visibility = 'private' then return jsonb_build_object('private', true, 'name', g.name); end if;
    if g.visibility = 'password' and (p_password is null or g.pass_hash is null or crypt(p_password, g.pass_hash) <> g.pass_hash) then
      return jsonb_build_object('locked', 'password', 'name', g.name, 'wrong', p_password is not null);
    end if;
    if g.visibility = 'paid' and not exists (select 1 from gallery_passes where gallery_id = g.id and user_id = auth.uid()) then
      return jsonb_build_object('locked', 'paid', 'name', g.name, 'id', g.id, 'fee', g.entry_fee, 'signed_in', auth.uid() is not null);
    end if;
  end if;
  return jsonb_build_object(
    'gallery', jsonb_build_object('id', g.id, 'name', g.name, 'slug', g.slug, 'visibility', g.visibility, 'entry_fee', g.entry_fee,
                                  'has_password', g.pass_hash is not null, 'owner_id', g.owner_id, 'settings', g.settings),
    'owner', (select jsonb_build_object('username', p.username, 'display_name', p.display_name) from profiles p where p.id = g.owner_id),
    'role', coalesce(r, 'viewer'),
    'rooms', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort, x.created_at) from rooms x where x.gallery_id = g.id), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(to_jsonb(i)) from items i where i.gallery_id = g.id), '[]'::jsonb)
  );
end $$;
grant execute on function public.get_shared_gallery(text, text) to anon, authenticated;

-- chủ phòng đặt chế độ xem: link / private / password (kèm mật khẩu) / paid (kèm số xu)
create or replace function public.set_access(p_gallery uuid, p_visibility text, p_password text, p_fee int) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_owner(p_gallery) then raise exception 'only the owner can do this'; end if;
  if p_visibility not in ('link', 'private', 'password', 'paid') then raise exception 'bad visibility'; end if;
  if p_visibility = 'password' and coalesce(length(p_password), 0) < 4 and (select pass_hash from galleries where id = p_gallery) is null then
    raise exception 'password too short';
  end if;
  if p_visibility = 'paid' and (p_fee is null or p_fee < 1 or p_fee > 100000) then raise exception 'bad fee'; end if;
  update galleries set visibility = p_visibility,
    pass_hash = case when p_visibility = 'password' and coalesce(length(p_password), 0) >= 4 then crypt(p_password, gen_salt('bf')) else pass_hash end,
    entry_fee = case when p_visibility = 'paid' then p_fee else entry_fee end
  where id = p_gallery;
end $$;
grant execute on function public.set_access(uuid, text, text, int) to authenticated;

-- khách mua vé vào phòng thu phí: xu chuyển cho chủ phòng
create or replace function public.buy_pass(p_gallery uuid) returns int
language plpgsql security definer set search_path = public as $$
declare g galleries; b int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into g from galleries where id = p_gallery;
  if not found or g.visibility <> 'paid' then raise exception 'not a paid gallery'; end if;
  if exists (select 1 from gallery_passes where gallery_id = g.id and user_id = auth.uid()) or public.is_member(g.id) then return public.my_wallet(); end if;
  b := public.spend_xu(g.entry_fee);
  insert into wallets (user_id) values (g.owner_id) on conflict do nothing;
  update wallets set balance = balance + g.entry_fee, updated_at = now() where user_id = g.owner_id;
  insert into gallery_passes (gallery_id, user_id) values (g.id, auth.uid());
  insert into donations (gallery_id, from_user, to_user, amount, message) values (g.id, auth.uid(), g.owner_id, g.entry_fee, 'Vé vào cửa');
  return b;
end $$;
grant execute on function public.buy_pass(uuid) to authenticated;

-- =====================================================================
--  Sảnh chính: danh sách phòng trưng bày công khai (miễn phí / mật khẩu / thu phí)
-- =====================================================================
create or replace function public.list_public_galleries(p_search text default null, p_limit int default 60) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(t order by t.hearts desc, t.created_at desc), '[]'::jsonb) from (
    select g.slug, g.name, g.visibility, g.entry_fee, g.created_at,
      p.username as owner_username, coalesce(p.display_name, p.username) as owner_name,
      (select count(*) from rooms r where r.gallery_id = g.id) as rooms,
      (select count(*) from items i where i.gallery_id = g.id) as items,
      (select count(*) from feedback f where f.gallery_id = g.id and f.kind <> 'rate') as hearts,
      (select round(avg(stars)::numeric, 1) from feedback f where f.gallery_id = g.id and f.kind = 'rate') as rating,
      (select i.path from items i where i.gallery_id = g.id and i.kind = 'image' order by i.updated_at desc limit 1) as cover,
      (select r.theme from rooms r where r.gallery_id = g.id order by r.sort, r.created_at limit 1) as theme,
      exists (select 1 from gallery_passes gp where gp.gallery_id = g.id and gp.user_id = auth.uid()) or public.is_member(g.id) as can_enter
    from galleries g join profiles p on p.id = g.owner_id
    where g.visibility in ('link', 'password', 'paid')
      and (p_search is null or p_search = '' or g.name ilike '%' || p_search || '%' or p.username ilike '%' || p_search || '%' or p.display_name ilike '%' || p_search || '%')
    order by g.created_at desc limit least(coalesce(p_limit, 60), 200)
  ) t;
$$;
grant execute on function public.list_public_galleries(text, int) to anon, authenticated;

-- =====================================================================
--  Kho đồ: vật phẩm đã mua nhưng chưa trưng bày (chạy lại cả file vẫn an toàn)
-- =====================================================================
create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('decor', 'model')),   -- decor = đồ đặt sàn có sẵn, model = mô hình .glb của cửa hàng
  item text not null,                                      -- loại đồ (ficus, lamp…) hoặc đường dẫn mô hình
  name text not null default '',
  thumb text,
  h real,
  created_at timestamptz not null default now()
);
create index if not exists inventory_user_idx on public.inventory (user_id);
alter table public.inventory enable row level security;
drop policy if exists "inventory self read" on public.inventory;
create policy "inventory self read" on public.inventory for select to authenticated using (user_id = auth.uid());

create or replace function public.inv_add(p_kind text, p_item text, p_name text, p_thumb text, p_h real, p_price int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare b int; r inventory;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_kind not in ('decor', 'model') or length(coalesce(p_item, '')) = 0 or length(p_item) > 300 then raise exception 'bad item'; end if;
  if coalesce(p_price, 0) > 0 then b := public.spend_xu(p_price); else b := public.my_wallet(); end if;
  insert into inventory (user_id, kind, item, name, thumb, h) values (auth.uid(), p_kind, p_item, left(coalesce(p_name, ''), 80), left(p_thumb, 300), p_h) returning * into r;
  return jsonb_build_object('item', to_jsonb(r), 'balance', b);
end $$;

-- lấy một món ra khỏi kho (để đặt vào phòng)
create or replace function public.inv_take(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r inventory;
begin
  delete from inventory where id = p_id and user_id = auth.uid() returning * into r;
  if r.id is null then raise exception 'not in your inventory'; end if;
  return to_jsonb(r);
end $$;

create or replace function public.inv_gift(p_id uuid, p_username text) returns text
language plpgsql security definer set search_path = public as $$
declare to_id uuid; nm text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select id, coalesce(display_name, username) into to_id, nm from profiles where username = lower(trim(p_username));
  if to_id is null then raise exception 'user not found'; end if;
  if to_id = auth.uid() then raise exception 'cannot gift yourself'; end if;
  update inventory set user_id = to_id, created_at = now() where id = p_id and user_id = auth.uid();
  if not found then raise exception 'not in your inventory'; end if;
  return nm;
end $$;
grant execute on function public.inv_add(text, text, text, text, real, int) to authenticated;
grant execute on function public.inv_take(uuid) to authenticated;
grant execute on function public.inv_gift(uuid, text) to authenticated;

-- =====================================================================
--  Lì xì: chủ phòng phát bao lì xì, khách bấm bắt để nhận xu ngẫu nhiên
-- =====================================================================
create table if not exists public.lixi_drops (
  id uuid primary key default gen_random_uuid(),
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  owner uuid not null references public.profiles(id) on delete cascade,
  total int not null check (total > 0),
  count int not null check (count between 1 and 50),
  left_xu int not null, left_count int not null,
  message text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes'
);
create index if not exists lixi_gallery_idx on public.lixi_drops (gallery_id);
create table if not exists public.lixi_claims (
  drop_id uuid not null references public.lixi_drops(id) on delete cascade,
  idx int not null, user_id uuid not null references public.profiles(id) on delete cascade,
  amount int not null, created_at timestamptz not null default now(),
  primary key (drop_id, idx), unique (drop_id, user_id)
);
alter table public.lixi_drops enable row level security;
alter table public.lixi_claims enable row level security;

-- trả lại xu của các đợt lì xì đã hết hạn mà chưa ai bắt hết
create or replace function public.lixi_refund() returns int
language plpgsql security definer set search_path = public as $$
declare d record; n int := 0;
begin
  for d in select * from lixi_drops where owner = auth.uid() and expires_at < now() and left_xu > 0 for update loop
    insert into wallets (user_id) values (d.owner) on conflict do nothing;
    update wallets set balance = balance + d.left_xu, updated_at = now() where user_id = d.owner;
    update lixi_drops set left_xu = 0, left_count = 0 where id = d.id; n := n + d.left_xu;
  end loop;
  return n;
end $$;

create or replace function public.lixi_create(p_room uuid, p_total int, p_count int, p_message text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare g uuid; b int; r lixi_drops;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select gallery_id into g from rooms where id = p_room;
  if g is null or not public.is_owner(g) then raise exception 'only the owner can do this'; end if;
  if p_count < 1 or p_count > 50 then raise exception 'bad count'; end if;
  if p_total < p_count or p_total > 10000000 then raise exception 'bad total'; end if;
  perform public.lixi_refund();
  b := public.spend_xu(p_total);
  insert into lixi_drops (gallery_id, room_id, owner, total, count, left_xu, left_count, message)
    values (g, p_room, auth.uid(), p_total, p_count, p_total, p_count, left(coalesce(p_message, ''), 120)) returning * into r;
  return jsonb_build_object('drop', to_jsonb(r), 'balance', b);
end $$;

create or replace function public.lixi_claim(p_drop uuid, p_idx int) returns int
language plpgsql security definer set search_path = public as $$
declare d lixi_drops; amt int; cap int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into d from lixi_drops where id = p_drop for update;
  if d.id is null or d.expires_at < now() or d.left_count <= 0 then raise exception 'gone'; end if;
  if d.owner = auth.uid() then raise exception 'own drop'; end if;
  if p_idx < 0 or p_idx >= d.count then raise exception 'bad index'; end if;
  if exists (select 1 from lixi_claims where drop_id = d.id and user_id = auth.uid()) then raise exception 'already claimed'; end if;
  if exists (select 1 from lixi_claims where drop_id = d.id and idx = p_idx) then raise exception 'taken'; end if;
  if d.left_count = 1 then amt := d.left_xu;
  else cap := greatest(1, least(d.left_xu - (d.left_count - 1), (2 * d.left_xu) / d.left_count)); amt := 1 + floor(random() * cap)::int; amt := least(amt, d.left_xu - (d.left_count - 1)); end if;
  insert into lixi_claims (drop_id, idx, user_id, amount) values (d.id, p_idx, auth.uid(), amt);
  update lixi_drops set left_xu = left_xu - amt, left_count = left_count - 1 where id = d.id;
  insert into wallets (user_id) values (auth.uid()) on conflict do nothing;
  update wallets set balance = balance + amt, updated_at = now() where user_id = auth.uid();
  return amt;
end $$;

create or replace function public.lixi_active(p_gallery uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'room_id', d.room_id, 'count', d.count, 'left_count', d.left_count, 'message', d.message, 'expires_at', d.expires_at,
    'owner_name', (select coalesce(display_name, username) from profiles where id = d.owner),
    'taken', (select coalesce(jsonb_agg(idx), '[]'::jsonb) from lixi_claims c where c.drop_id = d.id),
    'mine', exists (select 1 from lixi_claims c where c.drop_id = d.id and c.user_id = auth.uid()))), '[]'::jsonb)
  from lixi_drops d where d.gallery_id = p_gallery and d.expires_at > now() and d.left_count > 0 and public.can_view(p_gallery);
$$;
grant execute on function public.lixi_create(uuid, int, int, text) to authenticated;
grant execute on function public.lixi_claim(uuid, int) to authenticated;
grant execute on function public.lixi_refund() to authenticated;
grant execute on function public.lixi_active(uuid) to anon, authenticated;
