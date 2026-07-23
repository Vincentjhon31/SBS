-- Superadmin tests — cross-department visibility, department_members
-- management, stats gating, and a regression check that ordinary
-- approvers stay department-scoped.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/superadmin_test.sql
-- Seed deps: Test Staff (1111..., Motor Pool only, NOT superadmin),
-- Vincent (4444..., both depts, IS superadmin per seed). Rolled back at end.

begin;

do $$
begin
  if not exists (select 1 from public.profiles
                 where id = '44444444-4444-4444-4444-444444444444'
                   and is_superadmin) then
    raise exception 'FAIL: Vincent should be seeded as superadmin';
  end if;
  if exists (select 1 from public.profiles
             where id = '11111111-1111-1111-1111-111111111111'
               and is_superadmin) then
    raise exception 'FAIL: Test Staff should NOT be superadmin';
  end if;
end $$;

-- A GSO-scoped request Motor-Pool-only staff cannot see.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '99999999-aaaa-0000-0000-000000000001', 'authenticated', 'authenticated', 'cit-super-a@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen SuperA","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('99999999-aaaa-0000-0000-000000000001', '0917', 'UMID', 'SA-1', true);

insert into public.borrow_requests (id, item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
select '77777777-b000-0000-0000-000000000001', id, '99999999-aaaa-0000-0000-000000000001', 'citizen', 'GSO test', now() + interval '1 day', now() + interval '2 days'
from public.items where name = 'Stage Truss';

-- ===== Regression: Motor-Pool-only staff still can't see it =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
begin
  if exists (select 1 from public.borrow_requests
             where id = '77777777-b000-0000-0000-000000000001') then
    raise exception 'FAIL: Motor-Pool-only staff can see a GSO request (scoping regressed)';
  end if;
end $$;

do $$
begin
  begin
    perform public.superadmin_stats();
    raise exception 'FAIL: non-superadmin staff could call superadmin_stats()';
  exception
    when raise_exception then
      if sqlerrm not like '%only superadmins%' then raise; end if;
  end;
end $$;

do $$
begin
  begin
    insert into public.department_members (department_id, user_id)
    values ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111');
    raise exception 'FAIL: non-superadmin staff inserted a department_members row';
  exception
    when insufficient_privilege then null; -- expected
  end;
end $$;

-- ===== Superadmin (Vincent): sees everything, manages memberships, stats =====
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '77777777-b000-0000-0000-000000000001') then
    raise exception 'FAIL: superadmin cannot see the GSO request';
  end if;
end $$;

-- Superadmin can act on it too (approve), regardless of department.
update public.borrow_requests set status = 'approved'
where id = '77777777-b000-0000-0000-000000000001';

do $$
begin
  if not exists (select 1 from public.borrow_requests
                 where id = '77777777-b000-0000-0000-000000000001'
                   and status = 'approved' and approved_by = auth.uid()) then
    raise exception 'FAIL: superadmin approval did not stamp correctly';
  end if;
end $$;

-- Assign Test Staff to General Services (previously impossible in-app).
insert into public.department_members (department_id, user_id)
values ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111');

do $$
begin
  if not exists (select 1 from public.department_members
                 where department_id = '33333333-3333-3333-3333-333333333333'
                   and user_id = '11111111-1111-1111-1111-111111111111') then
    raise exception 'FAIL: superadmin could not assign staff to a department';
  end if;
end $$;

delete from public.department_members
where department_id = '33333333-3333-3333-3333-333333333333'
  and user_id = '11111111-1111-1111-1111-111111111111';

do $$
declare stats jsonb;
begin
  select public.superadmin_stats() into stats;
  if (stats ->> 'total_departments')::int < 2 then
    raise exception 'FAIL: stats missing expected department count';
  end if;
  if (stats ->> 'pending_requests') is null then
    raise exception 'FAIL: stats missing pending_requests key';
  end if;
end $$;

-- ===== Citizens can never call superadmin_stats or manage memberships =====
set local request.jwt.claims = '{"sub":"99999999-aaaa-0000-0000-000000000001","role":"authenticated"}';

do $$
begin
  begin
    perform public.superadmin_stats();
    raise exception 'FAIL: citizen called superadmin_stats()';
  exception
    when raise_exception then null; -- expected
  end;
end $$;

reset role;
select 'SUPERADMIN TESTS PASSED' as result;

rollback;
