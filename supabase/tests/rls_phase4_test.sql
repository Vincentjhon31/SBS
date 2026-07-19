-- Phase 4 tests — borrow request RLS + double-booking exclusion constraint.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase4_test.sql
-- Relies on seed: Test Staff (1111..., Motor Pool approver), items seeded.
-- Rolled back at the end.

begin;

-- Two throwaway citizens.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'authenticated', 'authenticated', 'cit-d@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen D","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'authenticated', 'authenticated', 'cit-e@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen E","user_type":"citizen"}', now(), now());

-- Verified citizen profiles (the Phase 5 gate blocks approving unverified
-- citizens; this test focuses on the overlap constraint, not the gate).
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '0917', 'UMID', 'D-1', true),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '0917', 'UMID', 'E-1', true);

-- ===== Citizen D requests the Multicab =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"dddddddd-dddd-dddd-dddd-dddddddddddd","role":"authenticated"}';

insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select id, auth.uid(), 'staff' /* trigger must overwrite this lie */, 'Barangay fiesta transport', now() + interval '1 day', now() + interval '3 days'
from public.items where name = 'Multicab';

-- Trigger corrected borrower_type and forced pending.
do $$
begin
  if not exists (
    select 1 from public.borrow_requests
    where borrower_id = auth.uid() and borrower_type = 'citizen' and status = 'pending'
  ) then
    raise exception 'FAIL: insert trigger did not normalize borrower_type/status';
  end if;
end $$;

-- Cannot create a request on someone else's behalf.
do $$
begin
  begin
    insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
    select id, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'citizen', 'x', now(), now() + interval '1 day'
    from public.items where name = 'Sound System';
    raise exception 'FAIL: created request for another borrower';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- Pending requests may overlap: Citizen E asks for the same window.
set local request.jwt.claims = '{"sub":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","role":"authenticated"}';
insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select id, auth.uid(), 'citizen', 'Transport for medical mission', now() + interval '1 day', now() + interval '3 days'
from public.items where name = 'Multicab';

-- Citizen E sees only their own request (not D's).
do $$
begin
  if (select count(*) from public.borrow_requests) <> 1 then
    raise exception 'FAIL: citizen sees requests that are not theirs';
  end if;
end $$;

-- ===== Staff visibility =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Test Staff (Motor Pool approver) sees both of this test's Multicab
-- requests (count scoped to test borrowers so leftover data can't skew it).
do $$
begin
  if (select count(*) from public.borrow_requests
      where borrower_id in ('dddddddd-dddd-dddd-dddd-dddddddddddd',
                            'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')) <> 2 then
    raise exception 'FAIL: approver does not see scoped requests, saw %',
      (select count(*) from public.borrow_requests
       where borrower_id in ('dddddddd-dddd-dddd-dddd-dddddddddddd',
                             'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'));
  end if;
end $$;

-- ===== Exclusion constraint (as superuser, simulating Phase 5 approvals) =====
reset role;

-- Approve D's request.
update public.borrow_requests set status = 'approved', due_at = requested_to
where borrower_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- Approving E's overlapping request must be impossible.
do $$
begin
  begin
    update public.borrow_requests set status = 'approved', due_at = requested_to
    where borrower_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
    raise exception 'FAIL: overlapping approval was accepted — double-booking possible!';
  exception
    when exclusion_violation then null; -- expected: constraint holds
  end;
end $$;

-- Adjacent windows are fine: reservation starting exactly when D's ends.
insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select id, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'citizen', 'Follow-on booking', now() + interval '3 days', now() + interval '4 days'
from public.items where name = 'Multicab';

update public.borrow_requests set status = 'approved', due_at = requested_to
where borrower_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' and purpose = 'Follow-on booking';

-- Released still blocks: flip D to released, then try approving an overlap.
update public.borrow_requests set status = 'released', released_at = now()
where borrower_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

do $$
begin
  begin
    update public.borrow_requests set status = 'approved'
    where borrower_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
      and purpose = 'Transport for medical mission';
    raise exception 'FAIL: overlap with RELEASED reservation was accepted';
  exception
    when exclusion_violation then null; -- expected
  end;
end $$;

-- Reserved-windows RPC exposes windows without borrower identity.
set local role authenticated;
set local request.jwt.claims = '{"sub":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","role":"authenticated"}';
do $$
declare cnt integer;
begin
  select count(*) into cnt
  from public.item_reserved_windows((select id from public.items where name = 'Multicab'));
  if cnt <> 2 then
    raise exception 'FAIL: reserved windows RPC returned % rows, expected 2', cnt;
  end if;
end $$;

reset role;
select 'PHASE 4 TESTS PASSED' as result;

rollback;
