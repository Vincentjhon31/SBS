-- create_department(): staff creates a department and is auto-enrolled as
-- its approver; citizens can't create one. Rolled back at the end.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/create_department_test.sql
-- Seed deps: Test Staff (1111..., staff).

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '77777777-dead-0000-0000-000000000001', 'authenticated', 'authenticated', 'cit-crdept@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen CrDept","user_type":"citizen"}', now(), now());

-- ===== A citizen cannot create a department =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"77777777-dead-0000-0000-000000000001","role":"authenticated"}';
do $$
begin
  begin
    perform public.create_department('Citizen Dept Attempt');
    raise exception 'FAIL: citizen created a department';
  exception when raise_exception then
    if sqlerrm not like '%not authorized%' then raise; end if;
  end;
end $$;

-- ===== Staff creates a department and is auto-enrolled as approver =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
declare
  new_dept uuid;
begin
  new_dept := public.create_department('Auto-Enroll Test Dept');

  if not exists (select 1 from public.departments where id = new_dept and name = 'Auto-Enroll Test Dept') then
    raise exception 'FAIL: department was not created';
  end if;

  if not exists (
    select 1 from public.department_members
    where department_id = new_dept
      and user_id = '11111111-1111-1111-1111-111111111111'
      and role = 'approver'
  ) then
    raise exception 'FAIL: creator was not enrolled as approver';
  end if;

  if not public.can_manage_item_dept(new_dept) then
    raise exception 'FAIL: creator cannot manage the department they just created';
  end if;
end $$;

reset role;
select 'CREATE DEPARTMENT TESTS PASSED' as result;

rollback;
