-- =====================================================================
-- ESTATE MANAGER v2 — "Publik lihat, Admin ubah"
-- Jalankan di: Supabase Dashboard -> SQL Editor -> Run
-- Aman dijalankan di database yang sudah ada (tidak menghapus kegiatan).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1. Tabel sesi (token admin). TIDAK bisa diakses publik.
-- ---------------------------------------------------------------------
create table if not exists public.sessions (
  token      uuid primary key default gen_random_uuid(),
  username   text not null,
  role       text not null default 'petugas',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);
alter table public.sessions enable row level security;
-- sengaja tanpa policy: anon tidak bisa membaca/menulis tabel ini

-- ---------------------------------------------------------------------
-- 2. Helper: apakah permintaan ini datang dari admin yang login?
--    Membaca header "x-estate-token" yang dikirim aplikasi.
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.sessions s
    where s.token::text = coalesce(current_setting('request.headers', true)::json ->> 'x-estate-token', '')
      and s.role = 'admin'
      and s.expires_at > now()
  );
$$;

-- ---------------------------------------------------------------------
-- 3. LOGIN -> mengembalikan token
-- ---------------------------------------------------------------------
drop function if exists public.app_login(text, text);
create or replace function public.app_login(p_username text, p_password text)
returns table (token uuid, username text, name text, role text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_name text; v_role text; v_user text := lower(trim(p_username)); v_tok uuid;
begin
  select u.name, u.role into v_name, v_role
  from public.users u
  where u.username = v_user and u.pw = crypt(p_password, u.pw)
  limit 1;

  if v_name is null then
    return;  -- username / sandi salah -> hasil kosong
  end if;

  insert into public.sessions (username, role)
  values (v_user, v_role)
  returning sessions.token into v_tok;

  return query select v_tok, v_user, v_name, v_role;
end $$;

-- ---------------------------------------------------------------------
-- 4. LOGOUT
-- ---------------------------------------------------------------------
create or replace function public.app_logout(p_token uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.sessions where token = p_token;
$$;

-- ---------------------------------------------------------------------
-- 4b. SESI AKTIF — mengembalikan info user dari token yang dikirim
--     (dipakai aplikasi saat membuka ulang halaman)
-- ---------------------------------------------------------------------
create or replace function public.app_session()
returns table (username text, name text, role text)
language sql stable security definer set search_path = public, extensions as $$
  select s.username, u.name, s.role
  from public.sessions s
  join public.users u on u.username = s.username
  where s.token::text = coalesce(current_setting('request.headers', true)::json ->> 'x-estate-token', '')
    and s.expires_at > now()
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- 5. Buat pengguna — hanya admin, ATAU saat belum ada pengguna (bootstrap)
-- ---------------------------------------------------------------------
create or replace function public.app_create_user(p_name text, p_username text, p_password text, p_role text)
returns table (id uuid, username text, name text, role text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_user text := lower(trim(p_username));
begin
  if not (public.is_admin() or (select count(*) from public.users) = 0) then
    raise exception 'hanya admin yang boleh menambah pengguna';
  end if;
  if v_user = '' or coalesce(trim(p_name),'') = '' then
    raise exception 'nama dan username wajib diisi';
  end if;
  if length(coalesce(p_password,'')) < 6 then
    raise exception 'kata sandi minimal 6 karakter';
  end if;
  if exists (select 1 from public.users u where u.username = v_user) then
    raise exception 'username sudah dipakai';
  end if;
  return query
    insert into public.users (username, name, pw, role)
    values (v_user, trim(p_name), crypt(p_password, gen_salt('bf')),
            case when p_role = 'admin' then 'admin' else 'petugas' end)
    returning users.id, users.username, users.name, users.role;
end $$;

-- ---------------------------------------------------------------------
-- 6. Fungsi lain — wajib admin
-- ---------------------------------------------------------------------
create or replace function public.app_count_users()
returns integer language sql security definer set search_path = public as $$
  select count(*)::int from public.users;
$$;

create or replace function public.app_list_users()
returns table (id uuid, username text, name text, role text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'hanya admin'; end if;
  return query select u.id, u.username, u.name, u.role, u.created_at
    from public.users u order by u.created_at;
end $$;

create or replace function public.app_set_password(p_username text, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_admin() then raise exception 'hanya admin'; end if;
  if length(coalesce(p_password,'')) < 6 then raise exception 'kata sandi minimal 6 karakter'; end if;
  update public.users set pw = crypt(p_password, gen_salt('bf'))
  where username = lower(trim(p_username));
end $$;

create or replace function public.app_delete_user(p_username text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'hanya admin'; end if;
  delete from public.users where username = lower(trim(p_username));
end $$;

-- ---------------------------------------------------------------------
-- 7. RLS: publik BOLEH BACA, hanya admin yang boleh TULIS
-- ---------------------------------------------------------------------
alter table public.activities enable row level security;
alter table public.photos     enable row level security;
alter table public.docs       enable row level security;

drop policy if exists activities_all on public.activities;
drop policy if exists activities_read on public.activities;
drop policy if exists activities_insert on public.activities;
drop policy if exists activities_update on public.activities;
drop policy if exists activities_delete on public.activities;
create policy activities_read   on public.activities for select to anon, authenticated using (true);
create policy activities_insert on public.activities for insert to anon, authenticated with check (public.is_admin());
create policy activities_update on public.activities for update to anon, authenticated using (public.is_admin()) with check (public.is_admin());
create policy activities_delete on public.activities for delete to anon, authenticated using (public.is_admin());

drop policy if exists photos_all on public.photos;
drop policy if exists photos_read on public.photos;
drop policy if exists photos_insert on public.photos;
drop policy if exists photos_update on public.photos;
drop policy if exists photos_delete on public.photos;
create policy photos_read   on public.photos for select to anon, authenticated using (true);
create policy photos_insert on public.photos for insert to anon, authenticated with check (public.is_admin());
create policy photos_update on public.photos for update to anon, authenticated using (public.is_admin()) with check (public.is_admin());
create policy photos_delete on public.photos for delete to anon, authenticated using (public.is_admin());

drop policy if exists docs_all on public.docs;
drop policy if exists docs_read on public.docs;
drop policy if exists docs_insert on public.docs;
drop policy if exists docs_update on public.docs;
drop policy if exists docs_delete on public.docs;
create policy docs_read   on public.docs for select to anon, authenticated using (true);
create policy docs_insert on public.docs for insert to anon, authenticated with check (public.is_admin());
create policy docs_update on public.docs for update to anon, authenticated using (public.is_admin()) with check (public.is_admin());
create policy docs_delete on public.docs for delete to anon, authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- 8. Storage: publik boleh lihat file, hanya admin yang boleh unggah/hapus
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('estate', 'estate', true)
on conflict (id) do update set public = true;

drop policy if exists estate_read   on storage.objects;
drop policy if exists estate_insert on storage.objects;
drop policy if exists estate_update on storage.objects;
drop policy if exists estate_delete on storage.objects;

create policy estate_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'estate');
create policy estate_insert on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'estate' and public.is_admin());
create policy estate_update on storage.objects
  for update to anon, authenticated using (bucket_id = 'estate' and public.is_admin());
create policy estate_delete on storage.objects
  for delete to anon, authenticated using (bucket_id = 'estate' and public.is_admin());

-- ---------------------------------------------------------------------
-- 9. Bersihkan sesi kedaluwarsa (opsional)
-- ---------------------------------------------------------------------
delete from public.sessions where expires_at < now();
