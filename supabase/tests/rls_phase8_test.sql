-- Phase 8 tests — items_status() state derivation.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase8_test.sql
-- Rolled back at the end.

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-dddd-dddd-dddd-dddddddddddd', 'authenticated', 'authenticated', 'cit-k@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen K","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('99999999-dddd-dddd-dddd-dddddddddddd', '0917', 'UMID', 'K-1', true);

-- Multicab: released and overdue -> 'overdue'
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '55555555-0000-0000-0000-000000000001', id, '99999999-dddd-dddd-dddd-dddddddddddd', 'citizen', 'x', now() - interval '2 days', now() - interval '1 day'
from public.items where name = 'Multicab';
update public.borrow_requests set status = 'approved' where id = '55555555-0000-0000-0000-000000000001';
update public.borrow_requests set status = 'released' where id = '55555555-0000-0000-0000-000000000001';
update public.borrow_requests set status = 'overdue' where id = '55555555-0000-0000-0000-000000000001';

-- Sound System: reservation window covering now, approved -> 'reserved_now'
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '55555555-0000-0000-0000-000000000002', id, '99999999-dddd-dddd-dddd-dddddddddddd', 'citizen', 'x', now() - interval '1 hour', now() + interval '5 hours'
from public.items where name = 'Sound System';
update public.borrow_requests set status = 'approved' where id = '55555555-0000-0000-0000-000000000002';

-- Gymnasium: future approved reservation -> 'available' with next_reserved_from
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '55555555-0000-0000-0000-000000000003', id, '99999999-dddd-dddd-dddd-dddddddddddd', 'citizen', 'x', now() + interval '3 days', now() + interval '4 days'
from public.items where name = 'Municipal Gymnasium';
update public.borrow_requests set status = 'approved' where id = '55555555-0000-0000-0000-000000000003';

-- Check as an authenticated citizen (RPC is definer; result has no identities).
set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-dddd-dddd-dddd-dddddddddddd","role":"authenticated"}';

do $$
declare r record;
begin
  select * into r from public.items_status() s
  join public.items i on i.id = s.item_id where i.name = 'Multicab';
  if r.status <> 'overdue' or r.current_due is null then
    raise exception 'FAIL: Multicab should be overdue with a due date, got %', r.status;
  end if;

  select * into r from public.items_status() s
  join public.items i on i.id = s.item_id where i.name = 'Sound System';
  if r.status <> 'reserved_now' then
    raise exception 'FAIL: Sound System should be reserved_now, got %', r.status;
  end if;

  select * into r from public.items_status() s
  join public.items i on i.id = s.item_id where i.name = 'Municipal Gymnasium';
  if r.status <> 'available' or r.next_reserved_from is null then
    raise exception 'FAIL: Gymnasium should be available with next_reserved_from, got %', r.status;
  end if;

  select * into r from public.items_status() s
  join public.items i on i.id = s.item_id where i.name = 'Stage Truss';
  if r.status <> 'available' or r.next_reserved_from is not null then
    raise exception 'FAIL: Stage Truss should be plain available, got %', r.status;
  end if;
end $$;

reset role;
select 'PHASE 8 TESTS PASSED' as result;

rollback;
