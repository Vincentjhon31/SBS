-- Phase 7 tests — notifications: decision triggers, due checks, RLS.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase7_test.sql
-- Rolled back at the end.

begin;

-- Verified citizen J with two requests on Motor Pool's Multicab.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', 'cit-j@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen J","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('99999999-cccc-cccc-cccc-cccccccccccc', '0917', 'UMID', 'J-1', true);

insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '66666666-0000-0000-0000-000000000001', id, '99999999-cccc-cccc-cccc-cccccccccccc', 'citizen', 'Notify approve', now() + interval '1 hour', now() + interval '12 hours'
from public.items where name = 'Multicab';
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '66666666-0000-0000-0000-000000000002', id, '99999999-cccc-cccc-cccc-cccccccccccc', 'citizen', 'Notify reject', now() + interval '2 days', now() + interval '3 days'
from public.items where name = 'Sound System';

-- Approve one, reject the other.
update public.borrow_requests set status = 'approved'
where id = '66666666-0000-0000-0000-000000000001';
update public.borrow_requests set status = 'rejected', rejected_reason = 'Not available'
where id = '66666666-0000-0000-0000-000000000002';

do $$
begin
  if not exists (select 1 from public.notifications
                 where recipient_id = '99999999-cccc-cccc-cccc-cccccccccccc'
                   and type = 'request_approved'
                   and borrow_request_id = '66666666-0000-0000-0000-000000000001') then
    raise exception 'FAIL: no approval notification';
  end if;
  if not exists (select 1 from public.notifications
                 where recipient_id = '99999999-cccc-cccc-cccc-cccccccccccc'
                   and type = 'request_rejected'
                   and body like '%Not available%') then
    raise exception 'FAIL: no rejection notification (with reason)';
  end if;
end $$;

-- Due-soon: request due in 12h -> one reminder, idempotent across reruns.
select public.run_due_checks();
select public.run_due_checks();

do $$
begin
  if (select count(*) from public.notifications
      where borrow_request_id = '66666666-0000-0000-0000-000000000001'
        and type = 'due_soon') <> 1 then
    raise exception 'FAIL: due_soon should fire exactly once, got %',
      (select count(*) from public.notifications
       where borrow_request_id = '66666666-0000-0000-0000-000000000001'
         and type = 'due_soon');
  end if;
end $$;

-- Overdue: push due_at into the past, run checks -> status flips and BOTH
-- borrower and Motor Pool approvers (Test Staff + Vincent) are notified.
update public.borrow_requests set due_at = now() - interval '1 hour'
where id = '66666666-0000-0000-0000-000000000001';

select public.run_due_checks();

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '66666666-0000-0000-0000-000000000001'
                   and status = 'overdue') then
    raise exception 'FAIL: overdue status was not flipped';
  end if;
  if not exists (select 1 from public.notifications
                 where borrow_request_id = '66666666-0000-0000-0000-000000000001'
                   and type = 'overdue'
                   and recipient_id = '99999999-cccc-cccc-cccc-cccccccccccc') then
    raise exception 'FAIL: borrower not notified of overdue';
  end if;
  if (select count(*) from public.notifications
      where borrow_request_id = '66666666-0000-0000-0000-000000000001'
        and type = 'overdue'
        and recipient_id in ('11111111-1111-1111-1111-111111111111',
                             '44444444-4444-4444-4444-444444444444')) <> 2 then
    raise exception 'FAIL: both Motor Pool approvers should be notified';
  end if;
end $$;

-- Rerunning must not duplicate overdue notifications (status already flipped).
select public.run_due_checks();
do $$
begin
  if (select count(*) from public.notifications
      where borrow_request_id = '66666666-0000-0000-0000-000000000001'
        and type = 'overdue') <> 3 then
    raise exception 'FAIL: overdue notifications duplicated on rerun';
  end if;
end $$;

-- The cron job is registered.
do $$
begin
  if not exists (select 1 from cron.job where jobname = 'sbs-due-checks') then
    raise exception 'FAIL: pg_cron job not scheduled';
  end if;
end $$;

-- ===== RLS: citizen sees only their notifications, can mark read =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

do $$
begin
  if (select count(*) from public.notifications) <> 4 then
    -- approved + rejected + due_soon + overdue (borrower copy only)
    raise exception 'FAIL: citizen sees % notifications, expected 4',
      (select count(*) from public.notifications);
  end if;
end $$;

update public.notifications set read_at = now() where type = 'request_approved';

do $$
begin
  if not exists (select 1 from public.notifications
                 where type = 'request_approved' and read_at is not null) then
    raise exception 'FAIL: citizen could not mark notification read';
  end if;
  -- Cannot forge new notifications.
  begin
    insert into public.notifications (recipient_id, type, title, body)
    values (auth.uid(), 'overdue', 'x', 'x');
    raise exception 'FAIL: citizen inserted a notification';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- Staff sees their own (overdue alerts), not the citizen's.
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  if (select count(*) from public.notifications where type <> 'overdue') <> 0 then
    raise exception 'FAIL: staff sees notifications not addressed to them';
  end if;
  if (select count(*) from public.notifications where type = 'overdue') <> 1 then
    raise exception 'FAIL: staff should see exactly their overdue alert';
  end if;
end $$;

reset role;
select 'PHASE 7 TESTS PASSED' as result;

rollback;
