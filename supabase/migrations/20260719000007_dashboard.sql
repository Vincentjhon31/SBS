-- Phase 8: Dashboard & History
-- Per-item live status for the registry/dashboard. Security definer so any
-- signed-in user gets availability info WITHOUT exposing borrower identity
-- (same privacy stance as item_reserved_windows).

create or replace function public.items_status()
returns table (
  item_id uuid,
  status text,
  current_due timestamptz,
  next_reserved_from timestamptz
)
language sql stable security definer
set search_path = public
as $$
  select
    i.id,
    case
      when exists (select 1 from borrow_requests br
                   where br.item_id = i.id and br.status = 'overdue')
        then 'overdue'
      when exists (select 1 from borrow_requests br
                   where br.item_id = i.id and br.status = 'released')
        then 'out'
      when exists (select 1 from borrow_requests br
                   where br.item_id = i.id and br.status = 'approved'
                     and br.requested_from <= now() and br.requested_to > now())
        then 'reserved_now'
      else 'available'
    end,
    (select min(br.due_at) from borrow_requests br
     where br.item_id = i.id and br.status in ('released', 'overdue')),
    (select min(br.requested_from) from borrow_requests br
     where br.item_id = i.id and br.status = 'approved'
       and br.requested_from > now())
  from items i
  where i.active;
$$;

revoke execute on function public.items_status() from public, anon;
grant execute on function public.items_status() to authenticated;
