-- Phase 5 tests — approval flow: transitions, verification gate, scoping.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase5_test.sql
-- Seed deps: Test Staff (1111..., Motor Pool), Vincent (4444..., both depts),
-- items Multicab (Motor Pool), Stage Truss (GSO). Rolled back at the end.

begin;

-- A citizen with an UNVERIFIED profile and a pending Multicab request.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'authenticated', 'authenticated', 'cit-f@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen F","user_type":"citizen"}', now(), now());

insert into public.citizen_profiles (id, contact_number, id_type, id_number)
values ('ffffffff-ffff-ffff-ffff-ffffffffffff', '0917', 'UMID', 'F-1');

insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '88888888-0000-0000-0000-000000000001', id, 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'citizen', 'Fiesta', now() + interval '1 day', now() + interval '2 days'
from public.items where name = 'Multicab';

-- And a pending request on the GSO item (from the same citizen).
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '88888888-0000-0000-0000-000000000002', id, 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'citizen', 'Stage setup', now() + interval '1 day', now() + interval '2 days'
from public.items where name = 'Stage Truss';

-- ===== Test Staff (Motor Pool only) =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Cannot approve unverified citizen (verification gate).
do $$
begin
  begin
    update public.borrow_requests set status = 'approved'
    where id = '88888888-0000-0000-0000-000000000001';
    raise exception 'FAIL: approved a request from an UNVERIFIED citizen';
  exception
    when raise_exception then
      if sqlerrm not like '%verified%' then raise; end if; -- expected gate
  end;
end $$;

-- Staff reads the citizen profile (verification data) and verifies them.
do $$
begin
  if not exists (select 1 from public.citizen_profiles
                 where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff') then
    raise exception 'FAIL: staff cannot read citizen profile for verification';
  end if;
end $$;

select public.verify_citizen('ffffffff-ffff-ffff-ffff-ffffffffffff');

do $$
begin
  if not exists (select 1 from public.citizen_profiles
                 where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                   and verified and verified_by = auth.uid()) then
    raise exception 'FAIL: verify_citizen did not record verifier';
  end if;
end $$;

-- Rejection requires a reason.
do $$
begin
  begin
    update public.borrow_requests set status = 'rejected'
    where id = '88888888-0000-0000-0000-000000000001';
    raise exception 'FAIL: rejection accepted without a reason';
  exception
    when raise_exception then
      if sqlerrm not like '%reason%' then raise; end if; -- expected
  end;
end $$;

-- Now approval works, and approved_by is stamped server-side.
update public.borrow_requests set status = 'approved'
where id = '88888888-0000-0000-0000-000000000001';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '88888888-0000-0000-0000-000000000001'
                   and status = 'approved'
                   and approved_by = auth.uid()
                   and due_at = requested_to) then
    raise exception 'FAIL: approval bookkeeping (approved_by/due_at) wrong';
  end if;
end $$;

-- Illegal jump: approved -> closed is not a valid transition.
do $$
begin
  begin
    update public.borrow_requests set status = 'closed'
    where id = '88888888-0000-0000-0000-000000000001';
    raise exception 'FAIL: illegal transition approved->closed accepted';
  exception
    when raise_exception then
      if sqlerrm not like '%invalid status transition%' then raise; end if;
  end;
end $$;

-- Scoping: Test Staff cannot even SEE the GSO request, let alone act on it.
do $$
declare updated integer;
begin
  if exists (select 1 from public.borrow_requests
             where id = '88888888-0000-0000-0000-000000000002') then
    raise exception 'FAIL: Motor Pool staff sees GSO-scoped request';
  end if;
  update public.borrow_requests set status = 'rejected', rejected_reason = 'x'
  where id = '88888888-0000-0000-0000-000000000002';
  get diagnostics updated = row_count;
  if updated > 0 then
    raise exception 'FAIL: Motor Pool staff updated a GSO request';
  end if;
end $$;

-- ===== Vincent (both departments) CAN act on the GSO request =====
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

update public.borrow_requests set status = 'rejected', rejected_reason = 'Truss under repair'
where id = '88888888-0000-0000-0000-000000000002';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '88888888-0000-0000-0000-000000000002'
                   and status = 'rejected') then
    raise exception 'FAIL: dual-dept approver could not reject GSO request';
  end if;
end $$;

-- ===== Citizens can neither verify nor approve =====
set local request.jwt.claims = '{"sub":"ffffffff-ffff-ffff-ffff-ffffffffffff","role":"authenticated"}';

do $$
begin
  begin
    perform public.verify_citizen('ffffffff-ffff-ffff-ffff-ffffffffffff');
    raise exception 'FAIL: citizen called verify_citizen';
  exception
    when raise_exception then
      if sqlerrm not like '%only staff%' then raise; end if; -- expected
  end;
end $$;

reset role;
select 'PHASE 5 TESTS PASSED' as result;

rollback;
