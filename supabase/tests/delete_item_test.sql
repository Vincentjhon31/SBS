-- delete_item(): staff deletes an unused item; blocked when it has
-- history; citizens can't delete. Rolled back at the end.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/delete_item_test.sql
-- Seed deps: Test Staff (1111..., staff), items seeded.

begin;

-- A throwaway unassigned item any staffer can manage, plus a verified
-- citizen to attach a borrow request to.
insert into public.items (id, name, created_by)
values ('11111111-dead-0000-0000-000000000001', 'Throwaway Item', '11111111-1111-1111-1111-111111111111');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '22222222-dead-0000-0000-000000000002', 'authenticated', 'authenticated', 'cit-del@test.local', 'x', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Citizen Del","user_type":"citizen"}', now(), now());
insert into public.citizen_profiles (id, contact_number, id_type, id_number, verified)
values ('22222222-dead-0000-0000-000000000002', '0917', 'UMID', 'DL-1', true);

-- ===== A citizen cannot delete an item =====
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-dead-0000-0000-000000000002","role":"authenticated"}';
do $$
begin
  begin
    perform public.delete_item('11111111-dead-0000-0000-000000000001');
    raise exception 'FAIL: citizen deleted an item';
  exception when raise_exception then
    if sqlerrm not like '%not authorized%' then raise; end if;
  end;
end $$;

-- ===== Staff deletes an unused item =====
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select public.delete_item('11111111-dead-0000-0000-000000000001');
do $$
begin
  if exists (select 1 from public.items where id = '11111111-dead-0000-0000-000000000001') then
    raise exception 'FAIL: unused item was not deleted';
  end if;
end $$;

-- ===== An item WITH borrow history is protected =====
-- Recreate the item and give it a request, then attempt delete.
set local role postgres;
insert into public.items (id, name, created_by)
values ('11111111-dead-0000-0000-000000000003', 'Used Item', '11111111-1111-1111-1111-111111111111');
insert into public.borrow_requests (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
values ('11111111-dead-0000-0000-000000000003', '22222222-dead-0000-0000-000000000002', 'citizen', 'x', now() + interval '1 day', now() + interval '2 days');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
do $$
begin
  begin
    perform public.delete_item('11111111-dead-0000-0000-000000000003');
    raise exception 'FAIL: deleted an item that has borrow history';
  exception when raise_exception then
    if sqlerrm not like '%borrow history%' then raise; end if;
  end;
end $$;
do $$
begin
  if not exists (select 1 from public.items where id = '11111111-dead-0000-0000-000000000003') then
    raise exception 'FAIL: item with history was removed';
  end if;
end $$;

reset role;
select 'DELETE ITEM TESTS PASSED' as result;

rollback;
