-- Department management: staff can already create/rename/deactivate
-- departments (existing RLS policies); this adds a real delete, with the
-- same safe-delete/deactivate-fallback shape as delete_item.
create or replace function public.delete_department(dept uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'not authorized to delete departments';
  end if;
  if not exists (select 1 from departments where id = dept) then
    raise exception 'department not found';
  end if;
  if exists (select 1 from items where owning_department_id = dept) then
    raise exception 'department has items assigned and cannot be deleted'
      using errcode = 'P0001', hint = 'deactivate';
  end if;
  if exists (select 1 from department_members where department_id = dept) then
    raise exception 'department has staff members and cannot be deleted'
      using errcode = 'P0001', hint = 'deactivate';
  end if;
  delete from departments where id = dept;
end;
$$;

revoke execute on function public.delete_department(uuid) from public, anon;
grant execute on function public.delete_department(uuid) to authenticated;
