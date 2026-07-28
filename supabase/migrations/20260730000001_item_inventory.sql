-- Inventory: items can now have more than one physical unit ("5 folding
-- chairs"), so more than one borrower can hold the same item concurrently
-- as long as total concurrent holds stay within quantity. No per-unit
-- identity is tracked (deliberately — matches the registry's lightweight,
-- no-SKU philosophy); it's a capacity count, not a serialized fleet.

alter table public.items
  add column quantity integer not null default 1 check (quantity >= 1);

-- Column grants are additive, so this just adds quantity to the existing
-- insert/update column sets rather than needing to restate them.
grant insert (quantity) on public.items to authenticated;
grant update (quantity) on public.items to authenticated;

-- ============================================================
-- Replace the single-unit exclusion constraint (zero overlap allowed)
-- with a capacity-aware trigger (up to `quantity` overlaps allowed). A
-- plain "count then compare" check would race under concurrent approvals
-- for the same item — `for update` locks the competing rows first, so a
-- second concurrent transaction blocks until the first commits/rolls
-- back and then re-counts with up-to-date data, the same safety the
-- exclusion constraint gave single-unit items.
-- ============================================================
alter table public.borrow_requests
  drop constraint no_overlapping_approved_reservations;

create or replace function public.check_item_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item_qty integer;
  overlapping_count integer;
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

  select count(*) into overlapping_count
  from borrow_requests
  where item_id = new.item_id
    and status in ('approved', 'released')
    and id <> new.id
    and tstzrange(requested_from, coalesce(requested_to, 'infinity'))
        && tstzrange(new.requested_from, coalesce(new.requested_to, 'infinity'));

  if overlapping_count >= item_qty then
    -- Reuses the exclusion constraint's errcode so the existing client
    -- catch (PostgrestException.code == '23P01' -> ReservationConflictException)
    -- keeps working with no Flutter-side change.
    raise exception 'no units available for this window'
      using errcode = '23P01';
  end if;

  return new;
end;
$$;

create trigger borrow_requests_check_capacity
before insert or update on public.borrow_requests
for each row execute function public.check_item_capacity();

-- ============================================================
-- items_status(): was a single worst-case label per item ("available" |
-- "reserved_now" | "out" | "overdue"), assuming exactly one unit. Now
-- also returns quantity + available_count, and the label only turns
-- alarming (overdue/out/reserved_now) once EVERY unit is occupied —
-- one overdue chair out of five shouldn't make the whole item look
-- unavailable.
-- ============================================================
-- CREATE OR REPLACE can't change a function's OUT-parameter shape.
drop function public.items_status();

create function public.items_status()
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
    select greatest(0, i.quantity - count(*))::integer as available_count
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

-- DROP FUNCTION also drops its grants, so these need restating.
revoke execute on function public.items_status() from public, anon;
grant execute on function public.items_status() to authenticated;
