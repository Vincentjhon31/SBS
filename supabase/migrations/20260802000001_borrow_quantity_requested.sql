-- Every request implicitly claimed exactly 1 unit of an item; now a
-- citizen can request several units at once (e.g. 3 of 5 folding chairs)
-- in a single request.

alter table public.borrow_requests
  add column quantity_requested integer not null default 1
    check (quantity_requested >= 1);

grant insert (quantity_requested) on public.borrow_requests to authenticated;

-- ============================================================
-- check_item_capacity(): sums unit demand instead of counting request
-- rows -- each overlapping row can now claim more than 1 unit.
-- ============================================================
create or replace function public.check_item_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item_qty integer;
  overlapping_qty integer;
begin
  if new.status not in ('approved', 'released') then
    return new;
  end if;

  perform 1 from borrow_requests
  where item_id = new.item_id
    and status in ('approved', 'released')
    and id <> new.id
    and tstzrange(requested_from, coalesce(requested_to, 'infinity'))
        && tstzrange(new.requested_from, coalesce(new.requested_to, 'infinity'))
  for update;

  select quantity into item_qty from items where id = new.item_id;

  select coalesce(sum(quantity_requested), 0) into overlapping_qty
  from borrow_requests
  where item_id = new.item_id
    and status in ('approved', 'released')
    and id <> new.id
    and tstzrange(requested_from, coalesce(requested_to, 'infinity'))
        && tstzrange(new.requested_from, coalesce(new.requested_to, 'infinity'));

  if overlapping_qty + new.quantity_requested > item_qty then
    -- Reuses the exclusion constraint's errcode so the existing client
    -- catch (PostgrestException.code == '23P01' -> ReservationConflictException)
    -- keeps working with no Flutter-side change.
    raise exception 'no units available for this window'
      using errcode = '23P01';
  end if;

  return new;
end;
$$;

-- ============================================================
-- items_status(): available_count now subtracts summed quantity_requested
-- instead of counting occupying rows. Same OUT shape as before, so
-- CREATE OR REPLACE (no DROP) is fine here.
-- ============================================================
create or replace function public.items_status()
returns table (
  item_id uuid,
  status text,
  current_due timestamptz,
  next_reserved_from timestamptz,
  quantity integer,
  available_count integer
)
language sql stable security definer
set search_path = public
as $$
  select
    i.id,
    case
      when occ.available_count > 0 then 'available'
      when exists (select 1 from borrow_requests br
                   where br.item_id = i.id and br.status = 'overdue')
        then 'overdue'
      when exists (select 1 from borrow_requests br
                   where br.item_id = i.id and br.status = 'released')
        then 'out'
      else 'reserved_now'
    end,
    (select min(br.due_at) from borrow_requests br
     where br.item_id = i.id and br.status in ('released', 'overdue')),
    (select min(br.requested_from) from borrow_requests br
     where br.item_id = i.id and br.status = 'approved'
       and br.requested_from > now()),
    i.quantity,
    occ.available_count
  from items i
  cross join lateral (
    select greatest(0, i.quantity - coalesce(sum(br.quantity_requested), 0))::integer
      as available_count
    from borrow_requests br
    where br.item_id = i.id
      and (
        br.status = 'overdue'
        or br.status = 'released'
        or (br.status = 'approved'
            and br.requested_from <= now()
            and (br.requested_to is null or br.requested_to > now()))
      )
  ) occ
  where i.active;
$$;

-- ============================================================
-- item_reserved_windows(): now also returns quantity_requested so the
-- client's conflict-warning heuristic can sum demand instead of just
-- counting overlapping windows. OUT shape changed, so this needs an
-- explicit DROP before CREATE.
-- ============================================================
drop function public.item_reserved_windows(uuid);

create function public.item_reserved_windows(item uuid)
returns table (
  reserved_from timestamptz,
  reserved_to timestamptz,
  quantity_requested integer
)
language sql stable security definer
set search_path = public
as $$
  select requested_from, requested_to, quantity_requested
  from borrow_requests
  where item_id = item
    and status in ('approved', 'released')
    and (requested_to is null or requested_to >= now())
  order by requested_from;
$$;

-- DROP FUNCTION also drops its grants, so these need restating.
revoke execute on function public.item_reserved_windows(uuid) from public, anon;
grant execute on function public.item_reserved_windows(uuid) to authenticated;
