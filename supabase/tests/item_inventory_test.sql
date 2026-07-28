-- Inventory capacity: up to `quantity` overlapping approved/released
-- reservations are allowed per item; the (quantity+1)th overlapping
-- approval is rejected the same way single-unit double-booking always
-- was (errcode 23P01, so the Flutter client's existing conflict handling
-- needs no changes). Quantity=1 items keep their old zero-overlap
-- behavior exactly.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/item_inventory_test.sql
-- Seed deps: Test Staff (1111..., staff, unscoped approver).

begin;

insert into public.items (id, name, quantity, created_by)
values ('99999999-cafe-0000-0000-000000000001', 'Folding Chair', 3, '11111111-1111-1111-1111-111111111111');

insert into public.items (id, name, quantity, created_by)
values ('99999999-cafe-0000-0000-000000000002', 'Single Multicab', 1, '11111111-1111-1111-1111-111111111111');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '99999999-cafe-1111-0000-000000000001', 'authenticated', 'authenticated', 'cit-inv-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Inv A","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-cafe-1111-0000-000000000002', 'authenticated', 'authenticated', 'cit-inv-b@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Inv B","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-cafe-1111-0000-000000000003', 'authenticated', 'authenticated', 'cit-inv-c@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Inv C","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-cafe-1111-0000-000000000004', 'authenticated', 'authenticated', 'cit-inv-d@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Inv D","user_type":"citizen"}', now(), now());

insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values
  ('99999999-cafe-1111-0000-000000000001', '0917', 'UMID', 'INV-1', true),
  ('99999999-cafe-1111-0000-000000000002', '0917', 'UMID', 'INV-2', true),
  ('99999999-cafe-1111-0000-000000000003', '0917', 'UMID', 'INV-3', true),
  ('99999999-cafe-1111-0000-000000000004', '0917', 'UMID', 'INV-4', true);

-- Four overlapping requests (same window) against the 3-unit chair.
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values
  ('99999999-cafe-2222-0000-000000000001', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000001', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days'),
  ('99999999-cafe-2222-0000-000000000002', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000002', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days'),
  ('99999999-cafe-2222-0000-000000000003', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000003', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days'),
  ('99999999-cafe-2222-0000-000000000004', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000004', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- ===== First 3 overlapping approvals succeed (fills all 3 units) =====
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-2222-0000-000000000001';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-2222-0000-000000000002';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-2222-0000-000000000003';

do $$
begin
  if (select count(*) from public.borrow_requests
      where item_id = '99999999-cafe-0000-0000-000000000001' and status = 'approved') <> 3 then
    raise exception 'FAIL: expected exactly 3 approved chairs';
  end if;
end $$;

-- ===== 4th overlapping approval is rejected (at capacity) =====
do $$
begin
  begin
    update public.borrow_requests set status = 'approved' where id = '99999999-cafe-2222-0000-000000000004';
    raise exception 'FAIL: 4th overlapping approval on a 3-unit item was accepted';
  exception
    when exclusion_violation then null; -- expected (errcode 23P01)
  end;
end $$;

-- ===== items_status() still shows all 3 free — the approved windows are
-- tomorrow, not happening right now =====
do $$
declare
  s record;
begin
  select * into s from public.items_status() where item_id = '99999999-cafe-0000-0000-000000000001';
  if s.quantity <> 3 or s.available_count <> 3 or s.status <> 'available' then
    raise exception 'FAIL: expected quantity=3 available_count=3 status=available for a future-dated hold, got quantity=%, available_count=%, status=%',
      s.quantity, s.available_count, s.status;
  end if;
end $$;

-- ===== items_status() counts CURRENT occupancy correctly for capacity>1:
-- 2 of the chair's 3 units approved for a window covering right now =====
reset role;
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values
  ('99999999-cafe-4444-0000-000000000001', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000001', 'citizen', 'x', now() - interval '1 hour', now() + interval '1 hour'),
  ('99999999-cafe-4444-0000-000000000002', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000002', 'citizen', 'x', now() - interval '1 hour', now() + interval '1 hour');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-4444-0000-000000000001';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-4444-0000-000000000002';

do $$
declare
  s record;
begin
  select * into s from public.items_status() where item_id = '99999999-cafe-0000-0000-000000000001';
  if s.available_count <> 1 or s.status <> 'available' then
    raise exception 'FAIL: expected available_count=1 status=available (1 of 3 chairs still free), got available_count=%, status=%',
      s.available_count, s.status;
  end if;
end $$;

reset role;

-- ===== A non-overlapping window on the same 3-unit item is unaffected —
-- a fresh request for a different date range, not the rejected one =====
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values ('99999999-cafe-2222-0000-000000000005', '99999999-cafe-0000-0000-000000000001', '99999999-cafe-1111-0000-000000000004', 'citizen', 'x', now() + interval '10 days', now() + interval '11 days');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-2222-0000-000000000005';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '99999999-cafe-2222-0000-000000000005' and status = 'approved') then
    raise exception 'FAIL: non-overlapping request on a full-for-a-different-window item should have been approved';
  end if;
end $$;

reset role;

-- ===== Quantity=1 item still blocks a 2nd overlapping approval (regression) =====
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values
  ('99999999-cafe-3333-0000-000000000001', '99999999-cafe-0000-0000-000000000002', '99999999-cafe-1111-0000-000000000001', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days'),
  ('99999999-cafe-3333-0000-000000000002', '99999999-cafe-0000-0000-000000000002', '99999999-cafe-1111-0000-000000000002', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
update public.borrow_requests set status = 'approved' where id = '99999999-cafe-3333-0000-000000000001';

do $$
begin
  begin
    update public.borrow_requests set status = 'approved' where id = '99999999-cafe-3333-0000-000000000002';
    raise exception 'FAIL: quantity=1 item allowed a 2nd overlapping approval';
  exception
    when exclusion_violation then null; -- expected
  end;
end $$;

reset role;
select 'ITEM INVENTORY TESTS PASSED' as result;

rollback;
