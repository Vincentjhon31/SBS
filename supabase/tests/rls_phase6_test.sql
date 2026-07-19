-- Phase 6 tests — evidence capture rules and visibility.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase6_test.sql
-- Rolled back at the end.

begin;

-- Verified citizen G with an APPROVED Multicab request; bystander citizen H.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '99999999-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'cit-g@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen G","user_type":"citizen"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'cit-h@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen H","user_type":"citizen"}', now(), now());

insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('99999999-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '0917', 'UMID', 'G-1', true);

insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '77777777-0000-0000-0000-000000000001', id, '99999999-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'citizen', 'Evidence test', now() + interval '1 day', now() + interval '2 days'
from public.items where name = 'Multicab';

update public.borrow_requests set status = 'approved'
where id = '77777777-0000-0000-0000-000000000001';

-- ===== Test Staff (Motor Pool approver) performs the release =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Release without acknowledgment must fail.
do $$
begin
  begin
    perform public.release_item('77777777-0000-0000-0000-000000000001',
      'p/b.jpg', 'p/i.jpg', false, 'v1');
    raise exception 'FAIL: release accepted without liability acknowledgment';
  exception
    when raise_exception then
      if sqlerrm not like '%acknowledgment%' then raise; end if;
  end;
end $$;

-- Release without photos must fail.
do $$
begin
  begin
    perform public.release_item('77777777-0000-0000-0000-000000000001',
      '', 'p/i.jpg', true, 'v1');
    raise exception 'FAIL: release accepted without borrower photo';
  exception
    when raise_exception then
      if sqlerrm not like '%photos are required%' then raise; end if;
  end;
end $$;

-- Proper release succeeds: evidence + ack + status flip.
select public.release_item('77777777-0000-0000-0000-000000000001',
  '77777777-0000-0000-0000-000000000001/release_borrower.jpg',
  '77777777-0000-0000-0000-000000000001/release_item.jpg',
  true, 'v1', 'Minor scratch on left door noted at handoff');

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '77777777-0000-0000-0000-000000000001'
                   and status = 'released' and released_at is not null) then
    raise exception 'FAIL: release did not flip status/released_at';
  end if;
  if not exists (select 1 from public.borrow_evidence
                 where borrow_request_id = '77777777-0000-0000-0000-000000000001'
                   and stage = 'release' and captured_by = auth.uid()) then
    raise exception 'FAIL: release evidence row missing';
  end if;
  if not exists (select 1 from public.liability_acknowledgments
                 where borrow_request_id = '77777777-0000-0000-0000-000000000001'
                   and acknowledged and terms_version = 'v1') then
    raise exception 'FAIL: liability acknowledgment missing';
  end if;
end $$;

-- Double release must fail (status is no longer approved).
do $$
begin
  begin
    perform public.release_item('77777777-0000-0000-0000-000000000001',
      'x/b.jpg', 'x/i.jpg', true, 'v1');
    raise exception 'FAIL: released the same request twice';
  exception
    when raise_exception then
      if sqlerrm not like '%only an approved request%' then raise; end if;
  end;
end $$;

-- Return closes the loop.
select public.return_item('77777777-0000-0000-0000-000000000001',
  '77777777-0000-0000-0000-000000000001/return_borrower.jpg',
  '77777777-0000-0000-0000-000000000001/return_item.jpg',
  'Returned with same scratch, no new damage');

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '77777777-0000-0000-0000-000000000001'
                   and status = 'returned' and returned_at is not null) then
    raise exception 'FAIL: return did not flip status/returned_at';
  end if;
  if (select count(*) from public.borrow_evidence
      where borrow_request_id = '77777777-0000-0000-0000-000000000001') <> 2 then
    raise exception 'FAIL: completed transaction must have exactly 2 evidence rows';
  end if;
end $$;

-- Storage: approver may write into the request's evidence folder...
insert into storage.objects (bucket_id, name, owner_id)
values ('evidence-photos', '77777777-0000-0000-0000-000000000001/release_borrower.jpg', auth.uid()::text);

-- ===== Borrower (Citizen G) sees their evidence =====
set local request.jwt.claims = '{"sub":"99999999-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

do $$
begin
  if (select count(*) from public.borrow_evidence) <> 2 then
    raise exception 'FAIL: borrower cannot see their own evidence';
  end if;
  if not exists (select 1 from public.liability_acknowledgments) then
    raise exception 'FAIL: borrower cannot see their acknowledgment';
  end if;
end $$;

-- ...but cannot capture evidence (RPC refuses non-approvers).
do $$
begin
  begin
    perform public.return_item('77777777-0000-0000-0000-000000000001', 'a', 'b');
    raise exception 'FAIL: borrower called return_item';
  exception
    when raise_exception then
      if sqlerrm not like '%scope%' then raise; end if;
  end;
end $$;

-- ...and cannot write photos into the evidence bucket.
do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('evidence-photos', '77777777-0000-0000-0000-000000000001/fake.jpg', auth.uid()::text);
    raise exception 'FAIL: borrower wrote into evidence bucket';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- ===== Bystander citizen H sees nothing =====
set local request.jwt.claims = '{"sub":"99999999-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

do $$
begin
  if exists (select 1 from public.borrow_evidence)
     or exists (select 1 from public.liability_acknowledgments) then
    raise exception 'FAIL: unrelated citizen can see evidence';
  end if;
end $$;

reset role;
select 'PHASE 6 TESTS PASSED' as result;

rollback;
