-- Phase 3 RLS tests — items registry scoping. Run after `supabase db reset`:
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/rls_phase3_test.sql
-- Relies on seed data: Test Staff (1111...) is Approver of Motor Pool (2222...),
-- not of General Services (3333...). Rolled back at the end.

begin;

-- A throwaway citizen for cross-role checks.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated', 'cit-c@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen C","user_type":"citizen"}', now(), now());

-- ===== Act as staff (Motor Pool approver) =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Reads all items (seeded 3).
do $$
begin
  if (select count(*) from public.items) < 3 then
    raise exception 'FAIL: staff cannot read seeded items';
  end if;
end $$;

-- Creates an unassigned item.
insert into public.items (name, created_by)
values ('Projector', auth.uid());

-- Creates an item in their own department.
insert into public.items (name, distinguishing_tag, owning_department_id, created_by)
values ('Service Van', 'SKB-777', '22222222-2222-2222-2222-222222222222', auth.uid());

-- Cannot create an item in a department they are NOT a member of.
do $$
begin
  begin
    insert into public.items (name, owning_department_id, created_by)
    values ('Sneaky Ladder', '33333333-3333-3333-3333-333333333333', auth.uid());
    raise exception 'FAIL: staff created item in a department they do not belong to';
  exception
    when insufficient_privilege then null; -- expected (RLS with-check)
  end;
end $$;

-- Updates an unassigned item (shared pool).
update public.items set category = 'Electronics' where name = 'Sound System';

-- Updates their department's item.
update public.items set distinguishing_tag = 'SKA-1234-A' where name = 'Multicab';

-- Duplicate guard: same name+tag differing only by case is rejected.
do $$
begin
  begin
    insert into public.items (name, created_by) values ('multicab  ', auth.uid());
    -- note: different tag makes it distinct; same (name, no-tag) vs seeded
    -- ('Multicab','SKA-1234') differs by tag, so this insert SUCCEEDS.
    null;
  exception
    when unique_violation then
      raise exception 'FAIL: distinct tag should make item unique';
  end;
  begin
    -- collides with 'Multicab' / 'SKA-1234-A' (tag updated above)
    insert into public.items (name, distinguishing_tag, created_by)
    values ('MULTICAB', 'ska-1234-a', auth.uid());
    raise exception 'FAIL: case-variant duplicate item was accepted';
  exception
    when unique_violation then null; -- expected
  end;
end $$;

-- Creates a department.
insert into public.departments (name) values ('Engineering Office');

-- ===== Act as citizen =====
set local request.jwt.claims = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

-- Citizens browse the registry.
do $$
begin
  if (select count(*) from public.items) < 3 then
    raise exception 'FAIL: citizen cannot browse items';
  end if;
end $$;

-- Citizens may add an unassigned item (self-growing registry)...
insert into public.items (name, created_by) values ('Folding Tables', auth.uid());

-- ...but not into a department...
do $$
begin
  begin
    insert into public.items (name, owning_department_id, created_by)
    values ('Fake Truck', '22222222-2222-2222-2222-222222222222', auth.uid());
    raise exception 'FAIL: citizen created a department-owned item';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- ...and never update or deactivate any item.
do $$
declare updated integer;
begin
  update public.items set name = 'Hacked' where name = 'Projector';
  get diagnostics updated = row_count;
  if updated > 0 then
    raise exception 'FAIL: citizen updated an item';
  end if;
end $$;

-- ...and cannot create departments.
do $$
begin
  begin
    insert into public.departments (name) values ('Citizen Dept');
    raise exception 'FAIL: citizen created a department';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- Citizen cannot write into the item-photos bucket.
do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('item-photos', 'sneak.jpg', auth.uid()::text);
    raise exception 'FAIL: citizen uploaded an item photo';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

reset role;
select 'PHASE 3 RLS TESTS PASSED' as result;

rollback;
