-- background_style preference: default, self-update, invalid value, cross-user block.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/background_style_test.sql
-- Rolled back at the end.

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '99999999-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'cit-bg-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Bg A","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'cit-bg-b@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Bg B","user_type":"citizen"}', now(), now());

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-3333-3333-3333-333333333333'
                   and background_style = 'glossy') then
    raise exception 'FAIL: default background_style should be glossy';
  end if;
end $$;

set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-3333-3333-3333-333333333333","role":"authenticated"}';

update public.profiles set background_style = 'blob' where id = auth.uid();

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-3333-3333-3333-333333333333'
                   and background_style = 'blob') then
    raise exception 'FAIL: self-update to blob did not persist';
  end if;
end $$;

update public.profiles set background_style = 'solid' where id = auth.uid();

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '99999999-3333-3333-3333-333333333333'
                   and background_style = 'solid') then
    raise exception 'FAIL: self-update to solid did not persist';
  end if;
end $$;

-- Invalid value rejected by the CHECK constraint.
do $$
begin
  begin
    update public.profiles set background_style = 'rainbow' where id = auth.uid();
    raise exception 'FAIL: invalid background_style value was accepted';
  exception
    when check_violation then null; -- expected
  end;
end $$;

-- Cannot change another user's background_style.
do $$
declare updated integer;
begin
  update public.profiles set background_style = 'blob'
  where id = '99999999-4444-4444-4444-444444444444';
  get diagnostics updated = row_count;
  if updated > 0 then
    raise exception 'FAIL: updated another user''s background_style';
  end if;
end $$;

reset role;
select 'BACKGROUND STYLE TESTS PASSED' as result;

rollback;
