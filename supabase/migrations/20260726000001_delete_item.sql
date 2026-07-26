-- Item deletion for the registry.
--
-- A hard delete is only safe for an item that was never borrowed —
-- borrow_requests.item_id references items, and that history is the LGU's
-- accountability record, so it must never be cascaded away. Items that
-- have any request are kept and should be DEACTIVATED (active = false)
-- instead, which the edit form and this RPC's error hint point staff to.
--
-- Runs as a security-definer RPC (not a table DELETE grant) so the
-- no-history rule can't be bypassed and the scoping matches item editing:
-- can_manage_item_dept() = staff who own that department (or the
-- unassigned pool).
create or replace function public.delete_item(item uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  dept uuid;
begin
  select owning_department_id into dept from items where id = item;
  if not found then
    raise exception 'item not found';
  end if;

  if not public.can_manage_item_dept(dept) then
    raise exception 'not authorized to delete this item';
  end if;

  if exists (select 1 from borrow_requests where item_id = item) then
    raise exception 'item has borrow history and cannot be deleted'
      using errcode = 'P0001', hint = 'deactivate';
  end if;

  delete from items where id = item;
end;
$$;

revoke execute on function public.delete_item(uuid) from public, anon;
grant execute on function public.delete_item(uuid) to authenticated;
