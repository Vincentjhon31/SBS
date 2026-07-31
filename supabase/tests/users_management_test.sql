-- Users management + username auth tests: username resolution, citizen
-- verify toggle, promote/demote, superadmin grant/revoke (incl. last-
-- superadmin guard), account deactivation scoping, broadcast, app
-- settings, and audit_log visibility.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/users_management_test.sql
-- Seed deps: Test Staff (1111..., NOT superadmin), Vincent (4444..., IS
-- superadmin). Rolled back at end.

begin;

-- A fresh citizen with a username, inserted the same minimal way the
-- superadmin test does (fires handle_new_user()).
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-bbbb-0000-0000-000000000001', 'authenticated', 'authenticated', 'juan@citizens.sbs.internal', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Juan Dela Cruz","username":"juandelacruz","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('99999999-bbbb-0000-0000-000000000001', '0917', 'UMID', 'JC-1', false);

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-bbbb-0000-0000-000000000001'
                   and username = 'juandelacruz') then
    raise exception 'FAIL: handle_new_user() did not store username from metadata';
  end if;
end $$;

-- ===== username_available / resolve_login_identifier (pre-auth, anon) =====
set local role anon;

do $$
begin
  if public.username_available('juandelacruz') then
    raise exception 'FAIL: username_available should be false for a taken username';
  end if;
  if not public.username_available('someoneelse') then
    raise exception 'FAIL: username_available should be true for a free username';
  end if;
  if public.resolve_login_identifier('juandelacruz') is distinct from 'juandelacruz@citizens.sbs.internal' then
    raise exception 'FAIL: resolve_login_identifier returned the wrong synthetic email';
  end if;
  if public.resolve_login_identifier('nosuchuser') is not null then
    raise exception 'FAIL: resolve_login_identifier should return null for an unknown username';
  end if;
  -- Case-insensitive.
  if public.resolve_login_identifier('JuanDelaCruz') is distinct from 'juandelacruz@citizens.sbs.internal' then
    raise exception 'FAIL: resolve_login_identifier should be case-insensitive';
  end if;
end $$;

reset role;

-- ===== set_citizen_verified: staff-only toggle =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select public.set_citizen_verified('99999999-bbbb-0000-0000-000000000001', true);

do $$
begin
  if not exists (select 1 from public.citizen_profiles
                 where id = '99999999-bbbb-0000-0000-000000000001' and verified) then
    raise exception 'FAIL: set_citizen_verified(true) did not verify';
  end if;
end $$;

select public.set_citizen_verified('99999999-bbbb-0000-0000-000000000001', false);

do $$
begin
  if exists (select 1 from public.citizen_profiles
             where id = '99999999-bbbb-0000-0000-000000000001' and verified) then
    raise exception 'FAIL: set_citizen_verified(false) did not un-verify';
  end if;
end $$;

-- Citizens can never call it.
set local request.jwt.claims = '{"sub":"99999999-bbbb-0000-0000-000000000001","role":"authenticated"}';
do $$
begin
  begin
    perform public.set_citizen_verified('99999999-bbbb-0000-0000-000000000001', true);
    raise exception 'FAIL: a citizen verified themselves';
  exception
    when raise_exception then
      if sqlerrm not like '%only staff%' then raise; end if;
  end;
end $$;

-- ===== set_user_type: superadmin-only, cannot change own =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  begin
    perform public.set_user_type('99999999-bbbb-0000-0000-000000000001', 'staff');
    raise exception 'FAIL: non-superadmin staff changed a user_type';
  exception
    when raise_exception then
      if sqlerrm not like '%only superadmins%' then raise; end if;
  end;
end $$;

set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';
do $$
begin
  begin
    perform public.set_user_type('44444444-4444-4444-4444-444444444444', 'citizen');
    raise exception 'FAIL: superadmin changed their own user_type';
  exception
    when raise_exception then
      if sqlerrm not like '%own account%' then raise; end if;
  end;
end $$;

select public.set_user_type('99999999-bbbb-0000-0000-000000000001', 'staff');
do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-bbbb-0000-0000-000000000001' and user_type = 'staff') then
    raise exception 'FAIL: set_user_type did not promote to staff';
  end if;
end $$;
select public.set_user_type('99999999-bbbb-0000-0000-000000000001', 'citizen');

-- ===== set_superadmin: superadmin-only, cannot revoke the last one =====
do $$
begin
  begin
    perform public.set_superadmin('44444444-4444-4444-4444-444444444444', false);
    raise exception 'FAIL: revoked the last remaining superadmin';
  exception
    when raise_exception then
      if sqlerrm not like '%last remaining superadmin%' then raise; end if;
  end;
end $$;

-- Grant to Test Staff, then it's safe to revoke Vincent's (two exist).
select public.set_superadmin('11111111-1111-1111-1111-111111111111', true);
select public.set_superadmin('44444444-4444-4444-4444-444444444444', false);
do $$
begin
  if exists (select 1 from public.profiles
             where id = '44444444-4444-4444-4444-444444444444' and is_superadmin) then
    raise exception 'FAIL: set_superadmin(false) did not revoke';
  end if;
  if not exists (select 1 from public.profiles
                 where id = '11111111-1111-1111-1111-111111111111' and is_superadmin) then
    raise exception 'FAIL: set_superadmin(true) did not grant';
  end if;
end $$;
-- Restore original seed state for downstream assertions.
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select public.set_superadmin('44444444-4444-4444-4444-444444444444', true);
select public.set_superadmin('11111111-1111-1111-1111-111111111111', false);

-- ===== set_account_active: staff can deactivate citizens; only
-- superadmin can deactivate staff; no self-deactivation =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select public.set_account_active('99999999-bbbb-0000-0000-000000000001', false);
do $$
begin
  if exists (select 1 from public.profiles
             where id = '99999999-bbbb-0000-0000-000000000001' and active) then
    raise exception 'FAIL: staff could not deactivate a citizen';
  end if;
end $$;
select public.set_account_active('99999999-bbbb-0000-0000-000000000001', true);

do $$
begin
  begin
    perform public.set_account_active('11111111-1111-1111-1111-111111111111', false);
    raise exception 'FAIL: staff deactivated their own account';
  exception
    when raise_exception then
      if sqlerrm not like '%own account%' then raise; end if;
  end;
end $$;

do $$
begin
  begin
    perform public.set_account_active('44444444-4444-4444-4444-444444444444', false);
    raise exception 'FAIL: regular staff deactivated another staff account';
  exception
    when raise_exception then
      if sqlerrm not like '%only superadmins%' then raise; end if;
  end;
end $$;

-- ===== broadcast_announcement: staff-only, citizens only, active only =====
select public.broadcast_announcement('Office closed', 'Closed for a holiday.');

-- notifications RLS is strictly self-scoped (no staff-wide read policy),
-- so verifying delivery to someone else's inbox needs to bypass RLS.
reset role;
do $$
begin
  if not exists (select 1 from public.notifications
                 where recipient_id = '99999999-bbbb-0000-0000-000000000001'
                   and type = 'announcement' and title = 'Office closed') then
    raise exception 'FAIL: broadcast did not reach the citizen';
  end if;
  if exists (select 1 from public.notifications
             where recipient_id = '11111111-1111-1111-1111-111111111111'
               and type = 'announcement') then
    raise exception 'FAIL: broadcast reached a staff account (should be citizens only)';
  end if;
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

set local request.jwt.claims = '{"sub":"99999999-bbbb-0000-0000-000000000001","role":"authenticated"}';
do $$
begin
  begin
    perform public.broadcast_announcement('x', 'y');
    raise exception 'FAIL: a citizen sent a broadcast';
  exception
    when raise_exception then
      if sqlerrm not like '%only staff%' then raise; end if;
  end;
end $$;

-- ===== set_app_setting: superadmin-only =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  begin
    perform public.set_app_setting('liability_terms_version', 'v2');
    raise exception 'FAIL: non-superadmin staff edited a system setting';
  exception
    when raise_exception then
      if sqlerrm not like '%only superadmins%' then raise; end if;
  end;
end $$;

set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';
select public.set_app_setting('liability_terms_version', 'v2-test');
do $$
begin
  if not exists (select 1 from public.app_settings
                 where key = 'liability_terms_version' and value = 'v2-test') then
    raise exception 'FAIL: set_app_setting did not update the value';
  end if;
end $$;

-- ===== audit_log: staff can read, citizens cannot, entries exist =====
do $$
declare v_count int;
begin
  select count(*) into v_count from public.audit_log;
  if v_count = 0 then
    raise exception 'FAIL: no audit_log entries were written by the actions above';
  end if;
end $$;

set local request.jwt.claims = '{"sub":"99999999-bbbb-0000-0000-000000000001","role":"authenticated"}';
do $$
declare v_count int;
begin
  select count(*) into v_count from public.audit_log;
  if v_count != 0 then
    raise exception 'FAIL: a citizen could read the audit log';
  end if;
end $$;

reset role;
select 'USERS MANAGEMENT TESTS PASSED' as result;

rollback;
