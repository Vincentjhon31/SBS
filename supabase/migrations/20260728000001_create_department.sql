-- Creating a department through the client left it with zero
-- department_members rows (there's no client insert path to that table),
-- so the creator couldn't assign items to it — can_manage_item_dept()
-- requires an approver membership, and the item form's department
-- dropdown only lists departments the caller belongs to. This RPC
-- atomically creates the department and enrolls the creator as its first
-- approver, the way any reasonable person would expect "I made this
-- department" to work.
create or replace function public.create_department(dept_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if not public.is_staff() then
    raise exception 'not authorized to create departments';
  end if;
  insert into departments (name) values (trim(dept_name)) returning id into new_id;
  insert into department_members (department_id, user_id, role)
  values (new_id, auth.uid(), 'approver');
  return new_id;
end;
$$;

revoke execute on function public.create_department(text) from public, anon;
grant execute on function public.create_department(text) to authenticated;
