begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare v_mode text;
begin
  -- Fresh profiles default to light rather than following the OS.
  select theme_mode into v_mode from public.profiles
   where id = '44444444-4444-4444-4444-444444444444';
  if v_mode != 'light' then
    raise exception 'FAIL: default theme_mode was % instead of light', v_mode;
  end if;

  -- A signed-in user can persist their own choice.
  update public.profiles set theme_mode = 'dark'
   where id = '44444444-4444-4444-4444-444444444444';
  select theme_mode into v_mode from public.profiles
   where id = '44444444-4444-4444-4444-444444444444';
  if v_mode != 'dark' then
    raise exception 'FAIL: theme_mode did not persist as dark';
  end if;

  -- Only the three known values are accepted.
  begin
    update public.profiles set theme_mode = 'neon'
     where id = '44444444-4444-4444-4444-444444444444';
    raise exception 'FAIL: an invalid theme_mode was accepted';
  exception
    when check_violation then null; -- expected
  end;
end $$;

-- A user cannot rewrite someone else's preference.
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
declare v_rows int;
begin
  update public.profiles set theme_mode = 'dark'
   where id = '44444444-4444-4444-4444-444444444444';
  get diagnostics v_rows = ROW_COUNT;
  if v_rows != 0 then
    raise exception 'FAIL: staff rewrote another user''s theme_mode';
  end if;
end $$;

reset role;
select 'THEME MODE TESTS PASSED' as result;
rollback;
