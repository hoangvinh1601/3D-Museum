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
  if p_amount < 0 or p_amount > 100000 then raise exception 'invalid amount'; end if;
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
