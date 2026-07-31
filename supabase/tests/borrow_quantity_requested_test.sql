-- quantity_requested: a single request can now claim more than 1 unit of
-- a multi-unit item — capacity math sums quantity_requested across
-- overlapping requests instead of counting rows.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/borrow_quantity_requested_test.sql
-- Seed deps: Test Staff (1111..., staff, unscoped approver).

begin;

insert into public.items (id, name, quantity, created_by)
values ('99999999-a9a0-0000-0000-000000000001', 'Stackable Table', 5, '11111111-1111-1111-1111-111111111111');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '99999999-a9a0-1111-0000-000000000001', 'authenticated', 'authenticated', 'cit-qty-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Qty A","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-a9a0-1111-0000-000000000002', 'authenticated', 'authenticated', 'cit-qty-b@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Qty B","user_type":"citizen"}', now(), now());

insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values
  ('99999999-a9a0-1111-0000-000000000001', '0917', 'UMID', 'QTY-1', true),
  ('99999999-a9a0-1111-0000-000000000002', '0917', 'UMID', 'QTY-2', true);

-- Default quantity_requested is 1 when omitted (regression).
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values ('99999999-a9a0-2222-0000-000000000000', '99999999-a9a0-0000-0000-000000000001', '99999999-a9a0-1111-0000-000000000001', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days');

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '99999999-a9a0-2222-0000-000000000000' and quantity_requested = 1) then
    raise exception 'FAIL: quantity_requested did not default to 1';
  end if;
end $$;

delete from public.borrow_requests where id = '99999999-a9a0-2222-0000-000000000000';

-- Requesting 0 or a negative quantity is rejected outright.
do $$
begin
  begin
    insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, quantity_requested)
    values ('99999999-a9a0-0000-0000-000000000001', '99999999-a9a0-1111-0000-000000000001', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days', 0);
    raise exception 'FAIL: quantity_requested=0 was accepted';
  exception
    when check_violation then null; -- expected
  end;
end $$;

-- A request for 2 of 5 units, approved.
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, quantity_requested)
values ('99999999-a9a0-2222-0000-000000000001', '99999999-a9a0-0000-0000-000000000001', '99999999-a9a0-1111-0000-000000000001', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days', 2);

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
update public.borrow_requests set status = 'approved' where id = '99999999-a9a0-2222-0000-000000000001';

-- A second, overlapping request for 4 more units would total 6 > 5 -- rejected.
reset role;
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to, quantity_requested)
values ('99999999-a9a0-2222-0000-000000000002', '99999999-a9a0-0000-0000-000000000001', '99999999-a9a0-1111-0000-000000000002', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days', 4);

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  begin
    update public.borrow_requests set status = 'approved' where id = '99999999-a9a0-2222-0000-000000000002';
    raise exception 'FAIL: 2 + 4 = 6 units on a 5-unit item was accepted';
  exception
    when exclusion_violation then null; -- expected (errcode 23P01)
  end;
end $$;

-- The same request for exactly 3 more units (2 + 3 = 5, exactly at
-- capacity) is accepted.
reset role;
update public.borrow_requests set quantity_requested = 3 where id = '99999999-a9a0-2222-0000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
update public.borrow_requests set status = 'approved' where id = '99999999-a9a0-2222-0000-000000000002';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '99999999-a9a0-2222-0000-000000000002' and status = 'approved') then
    raise exception 'FAIL: exact-capacity request (2+3=5 of 5) was rejected';
  end if;
end $$;

-- items_status() reflects the summed demand: 0 of 5 free for a window
-- covering right now once both approved requests are activated.
reset role;
update public.borrow_requests
set requested_from = now() - interval '1 hour', requested_to = now() + interval '1 hour'
where id in ('99999999-a9a0-2222-0000-000000000001', '99999999-a9a0-2222-0000-000000000002');

do $$
declare
  s record;
begin
  select * into s from public.items_status() where item_id = '99999999-a9a0-0000-0000-000000000001';
  if s.available_count <> 0 or s.status = 'available' then
    raise exception 'FAIL: expected available_count=0 (2+3=5 units in use), got available_count=%, status=%',
      s.available_count, s.status;
  end if;
end $$;

-- item_reserved_windows() surfaces quantity_requested per window.
do $$
declare
  total integer;
begin
  select coalesce(sum(quantity_requested), 0) into total
  from public.item_reserved_windows('99999999-a9a0-0000-0000-000000000001');
  if total <> 5 then
    raise exception 'FAIL: item_reserved_windows quantity_requested sum expected 5, got %', total;
  end if;
end $$;

reset role;
select 'BORROW QUANTITY REQUESTED TESTS PASSED' as result;

rollback;
