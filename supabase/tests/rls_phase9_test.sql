-- Phase 9 tests — retention purge, data export, deletion request flow.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase9_test.sql
-- Rolled back at the end.

begin;

-- Citizen L: old evidence (should purge) + a recent id photo (should NOT).
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-eeee-eeee-eeee-eeeeeeeeeeee', 'authenticated', 'authenticated', 'cit-l@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen L","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, id_photo_path, verified, created_at)
values ('99999999-eeee-eeee-eeee-eeeeeeeeeeee', '0917', 'UMID', 'L-1', '99999999-eeee-eeee-eeee-eeeeeeeeeeee/id_photo.jpg', true, now());

insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '44444444-a000-0000-0000-000000000001', id, '99999999-eeee-eeee-eeee-eeeeeeeeeeee', 'citizen', 'Old loan', now() - interval '400 days', now() - interval '399 days'
from public.items where name = 'Multicab';

insert into public.borrow_evidence (borrow_request_id, stage, photo_paths, captured_by, captured_at)
values (
  '44444444-a000-0000-0000-000000000001', 'release',
  array['44444444-a000-0000-0000-000000000001/release_borrower.jpg',
        '44444444-a000-0000-0000-000000000001/release_item.jpg'],
  '11111111-1111-1111-1111-111111111111',
  now() - interval '400 days'
);

-- A RECENT evidence row on a second request — must survive the purge.
insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '44444444-a000-0000-0000-000000000002', id, '99999999-eeee-eeee-eeee-eeeeeeeeeeee', 'citizen', 'Recent loan', now() - interval '5 days', now() - interval '4 days'
from public.items where name = 'Sound System';

insert into public.borrow_evidence (borrow_request_id, stage, photo_paths, captured_by, captured_at)
values (
  '44444444-a000-0000-0000-000000000002', 'release',
  array['44444444-a000-0000-0000-000000000002/release_borrower.jpg',
        '44444444-a000-0000-0000-000000000002/release_item.jpg'],
  '11111111-1111-1111-1111-111111111111',
  now() - interval '5 days'
);

-- Matching storage.objects rows so the purge has something to delete.
insert into storage.objects (bucket_id, name, owner_id) values
  ('evidence-photos', '44444444-a000-0000-0000-000000000001/release_borrower.jpg', '99999999-eeee-eeee-eeee-eeeeeeeeeeee'),
  ('evidence-photos', '44444444-a000-0000-0000-000000000001/release_item.jpg', '99999999-eeee-eeee-eeee-eeeeeeeeeeee'),
  ('evidence-photos', '44444444-a000-0000-0000-000000000002/release_borrower.jpg', '99999999-eeee-eeee-eeee-eeeeeeeeeeee'),
  ('evidence-photos', '44444444-a000-0000-0000-000000000002/release_item.jpg', '99999999-eeee-eeee-eeee-eeeeeeeeeeee'),
  ('id-photos', '99999999-eeee-eeee-eeee-eeeeeeeeeeee/id_photo.jpg', '99999999-eeee-eeee-eeee-eeeeeeeeeeee');

-- ===== Retention purge =====
select public.run_photo_retention();

do $$
begin
  if exists (select 1 from borrow_evidence
             where borrow_request_id = '44444444-a000-0000-0000-000000000001'
               and (cardinality(photo_paths) > 0 or purged_at is null)) then
    raise exception 'FAIL: old evidence photos were not purged';
  end if;
  if not exists (select 1 from borrow_evidence
                 where borrow_request_id = '44444444-a000-0000-0000-000000000002'
                   and cardinality(photo_paths) > 0 and purged_at is null) then
    raise exception 'FAIL: recent evidence was incorrectly purged';
  end if;
  -- ID photo: citizen's most recent activity is the -4-day request, well
  -- inside the retention window, so the ID photo must survive.
  if not exists (select 1 from citizen_profiles
                 where id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee'
                   and id_photo_path is not null) then
    raise exception 'FAIL: active citizen ID photo was incorrectly purged';
  end if;
end $$;

-- Now age out the citizen entirely (no activity within retention) and rerun.
update public.borrow_requests set created_at = now() - interval '400 days'
where borrower_id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee';

select public.run_photo_retention();

do $$
begin
  if exists (select 1 from citizen_profiles
             where id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee'
               and id_photo_path is not null) then
    raise exception 'FAIL: inactive citizen ID photo should have been purged';
  end if;
  -- Note: the storage.objects metadata row is NOT deleted here (Supabase's
  -- protect_delete trigger blocks raw-SQL deletes on that table) — only
  -- the app-level reference is severed. See migration comment for the
  -- documented physical-cleanup follow-up.
end $$;

-- ===== Export =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-eeee-eeee-eeee-eeeeeeeeeeee","role":"authenticated"}';

do $$
declare data jsonb;
begin
  select public.export_my_data() into data;
  if (data -> 'profile' ->> 'id') <> '99999999-eeee-eeee-eeee-eeeeeeeeeeee' then
    raise exception 'FAIL: export profile id mismatch';
  end if;
  if jsonb_array_length(data -> 'borrow_requests') <> 2 then
    raise exception 'FAIL: export should contain 2 borrow requests, got %',
      jsonb_array_length(data -> 'borrow_requests');
  end if;
  if (data -> 'citizen_profile') ? 'id_photo_path' then
    raise exception 'FAIL: export must not include the raw photo path';
  end if;
end $$;

-- ===== Deletion requests =====
insert into public.data_deletion_requests (user_id, reason)
values (auth.uid(), 'No longer using the service');

-- A second pending request is blocked (one-at-a-time).
do $$
begin
  begin
    insert into public.data_deletion_requests (user_id, reason)
    values (auth.uid(), 'again');
    raise exception 'FAIL: duplicate pending deletion request accepted';
  exception
    when unique_violation then null; -- expected
  end;
end $$;

-- Citizen cannot fulfill their own request.
do $$
declare req_id uuid;
begin
  select id into req_id from data_deletion_requests where user_id = auth.uid();
  begin
    perform public.complete_deletion_request(req_id);
    raise exception 'FAIL: citizen completed their own deletion request';
  exception
    when raise_exception then
      if sqlerrm not like '%only staff%' then raise; end if;
  end;
end $$;

-- Bystander citizen sees nothing.
reset role;
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-ffff-ffff-ffff-ffffffffffff', 'authenticated', 'authenticated', 'cit-m@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen M","user_type":"citizen"}', now(), now());
set local role authenticated;
set local request.jwt.claims = '{"sub":"99999999-ffff-ffff-ffff-ffffffffffff","role":"authenticated"}';
do $$
begin
  if exists (select 1 from data_deletion_requests) then
    raise exception 'FAIL: bystander citizen sees another user''s deletion request';
  end if;
end $$;

-- ===== Staff fulfills the request =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
begin
  if (select count(*) from data_deletion_requests where status = 'pending') <> 1 then
    raise exception 'FAIL: staff cannot see the pending deletion request';
  end if;
end $$;

do $$
declare req_id uuid;
begin
  select id into req_id from data_deletion_requests where status = 'pending';
  perform public.complete_deletion_request(req_id);

  if not exists (select 1 from profiles
                 where id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee'
                   and full_name = 'Deleted User') then
    raise exception 'FAIL: profile was not anonymized';
  end if;
  if not exists (select 1 from citizen_profiles
                 where id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee'
                   and contact_number = 'REDACTED' and id_number = 'REDACTED') then
    raise exception 'FAIL: citizen PII was not redacted';
  end if;
  if not exists (select 1 from data_deletion_requests
                 where id = req_id and status = 'completed'
                   and completed_by = '11111111-1111-1111-1111-111111111111') then
    raise exception 'FAIL: deletion request not marked completed correctly';
  end if;
  -- borrow_requests must survive: this is the accountability record.
  if (select count(*) from borrow_requests
      where borrower_id = '99999999-eeee-eeee-eeee-eeeeeeeeeeee') <> 2 then
    raise exception 'FAIL: borrow request history was deleted (should be anonymize-only)';
  end if;
end $$;

reset role;
select 'PHASE 9 TESTS PASSED' as result;

rollback;
