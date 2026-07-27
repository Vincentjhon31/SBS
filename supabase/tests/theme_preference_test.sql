-- theme_color preference: default, self-update, invalid value, cross-user block.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/theme_preference_test.sql
-- Rolled back at the end.

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '99999999-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'cit-theme-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Theme A","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'cit-theme-b@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Theme B","user_type":"citizen"}', now(), now());

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-1111-1111-1111-111111111111'
                   and theme_color = 'blue') then
    raise exception 'FAIL: default theme_color should be blue';
  end if;
end $$;

set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-1111-1111-1111-111111111111","role":"authenticated"}';

update public.profiles set theme_color = 'purple' where id = auth.uid();

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-1111-1111-1111-111111111111'
                   and theme_color = 'purple') then
    raise exception 'FAIL: self-update to purple did not persist';
  end if;
end $$;

-- Invalid value rejected by the CHECK constraint.
do $$
begin
  begin
    update public.profiles set theme_color = 'chartreuse' where id = auth.uid();
    raise exception 'FAIL: invalid theme_color value was accepted';
  exception
    when check_violation then null; -- expected
  end;
end $$;

-- The broadened palette (teal/coral/green) added alongside background_style
-- must all be accepted.
do $$
begin
  update public.profiles set theme_color = 'teal' where id = auth.uid();
  update public.profiles set theme_color = 'coral' where id = auth.uid();
  update public.profiles set theme_color = 'green' where id = auth.uid();
  if not exists (select 1 from public.profiles
                 where id = '99999999-1111-1111-1111-111111111111'
                   and theme_color = 'green') then
    raise exception 'FAIL: broadened palette value green did not persist';
  end if;
end $$;

-- Cannot change another user's theme_color.
do $$
declare updated integer;
begin
  update public.profiles set theme_color = 'purple'
  where id = '99999999-2222-2222-2222-222222222222';
  get diagnostics updated = row_count;
  if updated > 0 then
    raise exception 'FAIL: updated another user''s theme_color';
  end if;
end $$;

reset role;
select 'THEME PREFERENCE TESTS PASSED' as result;

rollback;
