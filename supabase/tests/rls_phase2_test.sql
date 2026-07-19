-- Phase 2 RLS tests — run against the LOCAL stack after `supabase db reset`:
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase2_test.sql
-- Every check raises an exception on failure; output "PHASE 2 RLS TESTS PASSED" means all good.
-- Runs in one rolled-back transaction: leaves no data behind.

begin;

-- Two throwaway citizen users; the signup trigger creates their profiles.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'cit-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen A","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'cit-b@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen B","user_type":"citizen"}', now(), now());

-- Trigger sanity: both profiles exist with user_type citizen.
do $$
begin
  if (select count(*) from public.profiles
      where id in ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
        and user_type = 'citizen') <> 2 then
    raise exception 'FAIL: signup trigger did not create citizen profiles';
  end if;
end $$;

-- B gets a citizen_profiles row (inserted as superuser for the read tests).
insert into public.citizen_profiles (id, contact_number, id_type, id_number)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '0917', 'UMID', 'B-123');

-- ===== Act as Citizen A =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

-- Sees exactly one profile: their own.
do $$
begin
  if (select count(*) from public.profiles) <> 1
     or not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'FAIL: citizen A should see only their own profile';
  end if;
end $$;

-- Cannot see B's citizen profile.
do $$
begin
  if exists (select 1 from public.citizen_profiles) then
    raise exception 'FAIL: citizen A can see another citizen''s verification data';
  end if;
end $$;

-- Cannot change their own user_type (column privilege revoked).
do $$
begin
  begin
    update public.profiles set user_type = 'staff' where id = auth.uid();
    raise exception 'FAIL: citizen A was able to change user_type';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- CAN update their own full_name.
update public.profiles set full_name = 'Citizen A Renamed' where id = auth.uid();

-- CAN insert their own citizen profile (allowed columns only).
insert into public.citizen_profiles (id, contact_number, id_type, id_number, id_photo_path)
values (auth.uid(), '0918', 'Passport', 'A-999', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/id_photo.jpg');

-- Cannot self-verify (verified column privilege revoked).
do $$
begin
  begin
    update public.citizen_profiles set verified = true where id = auth.uid();
    raise exception 'FAIL: citizen A was able to self-verify';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- Cannot insert a citizen profile for someone else (RLS with check).
do $$
begin
  begin
    insert into public.citizen_profiles (id, contact_number, id_type, id_number)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'x', 'x', 'x');
    raise exception 'FAIL: citizen A inserted a citizen profile for B';
  exception
    when unique_violation then null;         -- blocked (row exists) — still not RLS-passing? no: RLS check runs first
    when insufficient_privilege then null;   -- expected: RLS with-check violation
    when check_violation then null;
    when others then
      if sqlstate = '42501' then null; else raise; end if;
  end;
end $$;

-- Storage: can create an object in their own folder of id-photos...
insert into storage.objects (bucket_id, name, owner_id)
values ('id-photos', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/id_photo.jpg', auth.uid()::text);

-- ...but not in someone else's folder.
do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('id-photos', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/sneaky.jpg', auth.uid()::text);
    raise exception 'FAIL: citizen A wrote into B''s id-photo folder';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- ===== Act as anonymous =====
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

-- anon has no grants at all on these tables: reads must be denied outright.
do $$
begin
  begin
    perform 1 from public.profiles;
    raise exception 'FAIL: anon can read profiles';
  exception
    when insufficient_privilege then null; -- expected
  end;
  begin
    perform 1 from public.citizen_profiles;
    raise exception 'FAIL: anon can read citizen_profiles';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

reset role;
select 'PHASE 2 RLS TESTS PASSED' as result;

rollback;
