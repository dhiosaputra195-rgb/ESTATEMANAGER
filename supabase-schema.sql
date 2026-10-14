-- =====================================================================
-- ESTATE MANAGER · Golden Park  —  Skema Supabase
-- Jalankan seluruh isi file ini di: Supabase Dashboard → SQL Editor → Run
-- =====================================================================

-- 1. Ekstensi untuk hashing kata sandi
--    Di Supabase, pgcrypto dipasang di schema "extensions".
create extension if not exists pgcrypto with schema extensions;

-- =====================================================================
-- 2. TABEL
-- =====================================================================

-- Pengguna (admin & petugas)
create table if not exists public.users (
  id         uuid primary key default gen_random_uuid(),
  username   text unique not null,
  name       text not null,
  pw         text not null,                       -- hash bcrypt (pgcrypto)
  role       text not null default 'petugas' check (role in ('admin','petugas')),
  created_at timestamptz not null default now()
);

-- Pekerjaan / kegiatan
create table if not exists public.activities (
  id         uuid primary key default gen_random_uuid(),
  tgl        date not null,
  akt        text not null,
  ket        text default '',
  st         text not null default 'todo' check (st in ('todo','progress','done')),
  div        text default '',
  byr        numeric default 0,
  ven        text default '',
  pic        text default '',
  rutin      boolean default false,
  sampai     date,
  induk      uuid,
  oleh       text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Foto dokumentasi (menempel pada pekerjaan)
create table if not exists public.photos (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  url         text not null,
  name        text,
  created_at  timestamptz not null default now()
);

-- Lampiran dokumen (menempel pada pekerjaan)
create table if not exists public.docs (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  name        text not null,
  type        text,
  url         text not null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_activities_tgl on public.activities (tgl);
create index if not exists idx_photos_activity on public.photos (activity_id);
create index if not exists idx_docs_activity   on public.docs (activity_id);

-- =====================================================================
-- 3. ROW LEVEL SECURITY
--    users  : TIDAK bisa diakses langsung (hanya lewat fungsi di bawah)
--    lainnya: bisa dibaca/ditulis oleh aplikasi (anon key)
-- =====================================================================
alter table public.users      enable row level security;
alter table public.activities enable row level security;
alter table public.photos     enable row level security;
alter table public.docs       enable row level security;

drop policy if exists activities_all on public.activities;
create policy activities_all on public.activities
  for all to anon, authenticated using (true) with check (true);

drop policy if exists photos_all on public.photos;
create policy photos_all on public.photos
  for all to anon, authenticated using (true) with check (true);

drop policy if exists docs_all on public.docs;
create policy docs_all on public.docs
  for all to anon, authenticated using (true) with check (true);

-- (sengaja tidak ada policy untuk public.users → tertutup dari anon)

-- =====================================================================
-- 4. FUNGSI RPC (SECURITY DEFINER) — satu-satunya jalan ke tabel users
-- =====================================================================

-- Login
create or replace function public.app_login(p_username text, p_password text)
returns table (id uuid, username text, name text, role text)
language sql security definer set search_path = public, extensions as $$
  select u.id, u.username, u.name, u.role
  from public.users u
  where u.username = lower(trim(p_username))
    and u.pw = crypt(p_password, u.pw)
  limit 1;
$$;

-- Jumlah pengguna (untuk deteksi pertama kali)
create or replace function public.app_count_users()
returns integer language sql security definer set search_path = public, extensions as $$
  select count(*)::int from public.users;
$$;

-- Daftar pengguna (tanpa hash)
create or replace function public.app_list_users()
returns table (id uuid, username text, name text, role text, created_at timestamptz)
language sql security definer set search_path = public, extensions as $$
  select u.id, u.username, u.name, u.role, u.created_at
  from public.users u order by u.created_at;
$$;

-- Buat pengguna
create or replace function public.app_create_user(p_name text, p_username text, p_password text, p_role text)
returns table (id uuid, username text, name text, role text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_user text := lower(trim(p_username));
begin
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

-- Ganti kata sandi
create or replace function public.app_set_password(p_username text, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if length(coalesce(p_password,'')) < 6 then
    raise exception 'kata sandi minimal 6 karakter';
  end if;
  update public.users set pw = crypt(p_password, gen_salt('bf'))
  where username = lower(trim(p_username));
end $$;

-- Hapus pengguna
create or replace function public.app_delete_user(p_username text)
returns void language sql security definer set search_path = public, extensions as $$
  delete from public.users where username = lower(trim(p_username));
$$;

-- =====================================================================
-- 5. STORAGE — bucket publik untuk foto & lampiran
-- =====================================================================
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
  for insert to anon, authenticated with check (bucket_id = 'estate');
create policy estate_update on storage.objects
  for update to anon, authenticated using (bucket_id = 'estate');
create policy estate_delete on storage.objects
  for delete to anon, authenticated using (bucket_id = 'estate');

-- =====================================================================
-- 6. CONTOH DATA (opsional — hapus blok ini kalau tidak mau)
-- =====================================================================
insert into public.activities (tgl, akt, ket, st, div, byr, ven, pic)
values
  (make_date(extract(year from now())::int, 1,  6), 'Rapat perencanaan tahunan dengan pengelola', 'Susun jadwal perawatan fasilitas', 'done',     'Administrasi',           1500000, '',            ''),
  (make_date(extract(year from now())::int, 1, 15), 'Perawatan taman dan pemangkasan pohon',      'Area taman utama dan boulevard',   'done',     'Landscape',              3500000, 'CV Hijau Asri','Surya'),
  (make_date(extract(year from now())::int, 2, 10), 'Pengecekan lampu penerangan jalan',          'Ganti lampu yang mati di blok timur','done',    'Teknisi (ME)',           2250000, 'PT Terang Jaya','Dedi'),
  (make_date(extract(year from now())::int, 10, 5), 'Perbaikan paving block jalan utama',         'Titik amblas dekat gerbang',       'progress', 'Teknisi (ME)',           7800000, 'PT Karya Beton','Andi'),
  (make_date(extract(year from now())::int, 10,20), 'Pengecatan ulang pos keamanan',              'Menunggu material cat',            'todo',     'Keamanan',               1200000, '',            'Rudi'),
  (make_date(extract(year from now())::int, 11, 3), 'Servis pompa air dan tandon',                'Jadwal rutin tahunan',             'todo',     'Teknisi (ME)',           900000,  '',            'Dedi'),
  (make_date(extract(year from now())::int, 12,12), 'Evaluasi kinerja tahunan estate',            'Bahan laporan akhir tahun',        'todo',     'Administrasi',           0,       '',            '')
on conflict do nothing;
