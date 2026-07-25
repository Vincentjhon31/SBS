-- Use-window CHECKs: valid insert, each violation rejected, NULLs allowed.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/use_window_test.sql
-- Relies on seed items. Rolled back at the end.

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'cccccccc-0000-0000-0000-00000000cc01', 'authenticated', 'authenticated', 'cit-use@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen Use","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('cccccccc-0000-0000-0000-00000000cc01', '0917', 'UMID', 'U-1', true);

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-0000-0000-0000-00000000cc01","role":"authenticated"}';

-- ===== Valid: pickup one day before use, return on use-end =====
-- pickup = D+1, use = D+2..D+3, return = D+3.
insert into public.borrow_requests
  (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, use_from, use_to)
select id, auth.uid(), 'citizen', 'Fiesta',
  now() + interval '1 day', now() + interval '3 days',
  now() + interval '2 days', now() + interval '3 days'
from public.items where name = 'Multicab';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where borrower_id = auth.uid() and use_from is not null) then
    raise exception 'FAIL: valid use-window insert did not persist';
  end if;
end $$;

-- ===== NULL use window still allowed (legacy / walk-in shape) =====
insert into public.borrow_requests
  (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select id, auth.uid(), 'citizen', 'No use window',
  now() + interval '10 days', now() + interval '11 days'
from public.items where name = 'Sound System';

-- ===== Violation: use_to < use_from =====
do $$
begin
  begin
    insert into public.borrow_requests
      (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, use_from, use_to)
    select id, auth.uid(), 'citizen', 'bad order',
      now() + interval '1 day', now() + interval '5 days',
      now() + interval '4 days', now() + interval '2 days'
    from public.items where name = 'Canopy Tent';
    raise exception 'FAIL: accepted use_to < use_from';
  exception when check_violation then null; end;
end $$;

-- ===== Violation: pickup after use start =====
do $$
begin
  begin
    insert into public.borrow_requests
      (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, use_from, use_to)
    select id, auth.uid(), 'citizen', 'late pickup',
      now() + interval '3 days', now() + interval '5 days',
      now() + interval '2 days', now() + interval '4 days'
    from public.items where name = 'Canopy Tent';
    raise exception 'FAIL: accepted pickup after use start';
  exception when check_violation then null; end;
end $$;

-- ===== Violation: return before use end =====
do $$
begin
  begin
    insert into public.borrow_requests
      (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, use_from, use_to)
    select id, auth.uid(), 'citizen', 'early return',
      now() + interval '1 day', now() + interval '3 days',
      now() + interval '2 days', now() + interval '5 days'
    from public.items where name = 'Canopy Tent';
    raise exception 'FAIL: accepted return before use end';
  exception when check_violation then null; end;
end $$;

-- ===== Violation: advance pickup more than one day =====
do $$
begin
  begin
    insert into public.borrow_requests
      (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, use_from, use_to)
    select id, auth.uid(), 'citizen', 'too early',
      now() + interval '1 day', now() + interval '6 days',
      now() + interval '4 days', now() + interval '5 days'
    from public.items where name = 'Canopy Tent';
    raise exception 'FAIL: accepted advance pickup > 1 day';
  exception when check_violation then null; end;
end $$;

reset role;
select 'USE WINDOW TESTS PASSED' as result;

rollback;
