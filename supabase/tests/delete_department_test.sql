-- delete_department(): staff deletes an unused department; blocked when
-- items or members reference it; citizens can't delete. Rolled back at
-- the end.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/delete_department_test.sql
-- Seed deps: Test Staff (1111..., staff), Motor Pool department seeded.

begin;

insert into public.departments (id, name)
values ('33333333-dead-0000-0000-000000000001', 'Throwaway Dept');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '44444444-dead-0000-0000-000000000002', 'authenticated', 'authenticated', 'cit-deldept@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen DelDept","user_type":"citizen"}', now(), now());

-- ===== A citizen cannot delete a department =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-dead-0000-0000-000000000002","role":"authenticated"}';
do $$
begin
  begin
    perform public.delete_department('33333333-dead-0000-0000-000000000001');
    raise exception 'FAIL: citizen deleted a department';
  exception when raise_exception then
    if sqlerrm not like '%not authorized%' then raise; end if;
  end;
end $$;

-- ===== Staff deletes an unused department =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select public.delete_department('33333333-dead-0000-0000-000000000001');
do $$
begin
  if exists (select 1 from public.departments where id = '33333333-dead-0000-0000-000000000001') then
    raise exception 'FAIL: unused department was not deleted';
  end if;
end $$;

-- ===== A department with items assigned is protected =====
do $$
begin
  begin
    perform public.delete_department('22222222-2222-2222-2222-222222222222'); -- seeded Motor Pool
    raise exception 'FAIL: deleted a department that has items assigned';
  exception when raise_exception then
    if sqlerrm not like '%items assigned%' then raise; end if;
  end;
end $$;
do $$
begin
  if not exists (select 1 from public.departments where id = '22222222-2222-2222-2222-222222222222') then
    raise exception 'FAIL: department with items assigned was removed';
  end if;
end $$;

reset role;
select 'DELETE DEPARTMENT TESTS PASSED' as result;

rollback;
