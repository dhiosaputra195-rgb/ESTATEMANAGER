-- =====================================================================
-- PATCH: perbaikan fungsi app_create_user (error "column reference
--        username is ambiguous") — jalankan di SQL Editor, klik Run.
-- =====================================================================
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

-- (opsional) kosongkan 7 data contoh kalau tidak mau
-- delete from public.activities;
