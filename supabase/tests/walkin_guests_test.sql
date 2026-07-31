-- Walk-in guest borrower tests — creation, auto-approval, open-ended due
-- dates, double-booking still enforced, RLS isolation, and a regression
-- check that ordinary self-service requests still require a return date.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/walkin_guests_test.sql
-- Seed deps: Test Staff (1111..., Motor Pool only), Vincent (4444...,
-- both depts). Rolled back at the end.

begin;

-- ===== Citizens cannot create walk-in requests at all =====
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', 'cit-walkin@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen Walkin","user_type":"citizen"}', now(), now());

set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

do $$
begin
  begin
    perform public.create_guest_borrow_request(
      (select id from public.items where name = 'Multicab'),
      'Juan Dela Cruz', '123 Rizal St', '09171234567', null,
      'Errand', now(), now() + interval '2 hours', true
    );
    raise exception 'FAIL: citizen created a walk-in request';
  exception
    when raise_exception then
      if sqlerrm not like '%not authorized%' then raise; end if;
  end;
end $$;

-- ===== Motor-Pool-only staff: in-scope item works, out-of-scope blocked =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Consent required.
do $$
begin
  begin
    perform public.create_guest_borrow_request(
      (select id from public.items where name = 'Multicab'),
      'Ana Reyes', '45 Mabini St', '09181234567', null,
      'Barangay errand', now(), now() + interval '3 hours', false
    );
    raise exception 'FAIL: walk-in created without consent';
  exception
    when raise_exception then
      if sqlerrm not like '%consent%' then raise; end if;
  end;
end $$;

-- Out of scope (Stage Truss is GSO-owned; Test Staff is Motor Pool only).
do $$
begin
  begin
    perform public.create_guest_borrow_request(
      (select id from public.items where name = 'Stage Truss'),
      'Ben Cruz', '9 Luna St', '09191234567', null,
      'Event setup', now(), now() + interval '1 day', true
    );
    raise exception 'FAIL: out-of-scope staff created a walk-in request';
  exception
    when raise_exception then
      if sqlerrm not like '%not authorized%' then raise; end if;
  end;
end $$;

-- In scope, with a real return date: full happy path.
do $$
declare
  req_id uuid;
  g_id uuid;
begin
  select public.create_guest_borrow_request(
    (select id from public.items where name = 'Multicab'),
    '  Ana Reyes  ', ' 45 Mabini St ', ' 09181234567 ', '',
    'Barangay errand', now() + interval '10 days', now() + interval '10 days 2 hours', true
  ) into req_id;

  select guest_borrower_id into g_id from public.borrow_requests where id = req_id;
  if g_id is null then
    raise exception 'FAIL: request has no guest_borrower_id';
  end if;

  if not exists (select 1 from public.guest_borrowers
                 where id = g_id and full_name = 'Ana Reyes'
                   and address = '45 Mabini St' and contact_number = '09181234567'
                   and email is null and consented) then
    raise exception 'FAIL: guest_borrowers row wrong (trim/empty-email handling)';
  end if;

  if not exists (select 1 from public.borrow_requests
                 where id = req_id and status = 'approved'
                   and borrower_type = 'guest' and borrower_id is null
                   and approved_by = '11111111-1111-1111-1111-111111111111'
                   and due_at is not null) then
    raise exception 'FAIL: walk-in request not auto-approved correctly';
  end if;
end $$;

-- ===== Open-ended (indefinite) walk-in loan =====
do $$
declare
  req_id uuid;
begin
  select public.create_guest_borrow_request(
    (select id from public.items where name = 'Sound System'),
    'Carlo Santos', '7 Bonifacio St', '09201234567', 'carlo@example.com',
    'Fiesta, not sure how long', now() + interval '20 days', null, true
  ) into req_id;

  if not exists (select 1 from public.borrow_requests
                 where id = req_id and requested_to is null and status = 'approved') then
    raise exception 'FAIL: indefinite walk-in loan not created/approved correctly';
  end if;

  -- Release it (existing Phase 6 RPC — must still work with the new
  -- multi-photo signature).
  perform public.release_item(req_id, array['x/b.jpg'], true, 'v1');
  if not exists (select 1 from public.borrow_requests where id = req_id and status = 'released') then
    raise exception 'FAIL: indefinite walk-in loan did not release';
  end if;
end $$;

-- Indefinite loan must block ANY future reservation of that item.
do $$
begin
  begin
    insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
    select id, '11111111-1111-1111-1111-111111111111', 'staff', 'Conflict test', now() + interval '365 days', now() + interval '366 days'
    from public.items where name = 'Sound System';
    update public.borrow_requests set status = 'approved'
    where item_id = (select id from public.items where name = 'Sound System')
      and purpose = 'Conflict test';
    raise exception 'FAIL: a far-future reservation was approved despite an open-ended loan';
  exception
    when exclusion_violation then null; -- expected: exclusion constraint fires
  end;
end $$;

-- Reserved-windows RPC must surface the open-ended loan (not silently
-- drop it because requested_to is null).
do $$
declare cnt integer;
begin
  select count(*) into cnt from public.item_reserved_windows(
    (select id from public.items where name = 'Sound System')
  ) where reserved_to is null;
  if cnt <> 1 then
    raise exception 'FAIL: item_reserved_windows dropped the open-ended window';
  end if;
end $$;

-- ===== Regression: ordinary self-service inserts still require a due date =====
set local request.jwt.claims = '{"sub":"99999999-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

do $$
begin
  begin
    insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
    select id, '99999999-cccc-cccc-cccc-cccccccccccc', 'citizen', 'No due date attempt', now(), null
    from public.items where name = 'Multicab';
    raise exception 'FAIL: citizen self-service request accepted with no due date';
  exception
    when check_violation then null; -- expected
  end;
end $$;

-- A client can never even attempt to set guest_borrower_id directly (no
-- grant on that column — only the RPC, running security definer, ever
-- writes it), which is stronger than relying on the xor check alone.
do $$
declare some_guest_id uuid;
begin
  select id into some_guest_id from public.guest_borrowers limit 1;
  begin
    insert into public.borrow_requests (item_id, borrower_id, guest_borrower_id, borrower_type, purpose, requested_from, requested_to)
    select id, '99999999-cccc-cccc-cccc-cccccccccccc', some_guest_id, 'citizen', 'Both set', now(), now() + interval '1 hour'
    from public.items where name = 'Multicab';
    raise exception 'FAIL: client could set guest_borrower_id directly';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- ===== RLS: only staff can read guest_borrowers =====
do $$
begin
  if exists (select 1 from public.guest_borrowers) then
    raise exception 'FAIL: citizen can read guest_borrowers';
  end if;
end $$;

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  if not exists (select 1 from public.guest_borrowers where full_name = 'Ana Reyes') then
    raise exception 'FAIL: staff cannot read guest_borrowers';
  end if;
end $$;

reset role;
select 'WALK-IN GUEST TESTS PASSED' as result;

rollback;
