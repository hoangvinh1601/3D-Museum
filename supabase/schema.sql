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
