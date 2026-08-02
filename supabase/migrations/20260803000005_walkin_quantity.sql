-- Walk-in requests could only ever claim one unit.
--
-- When quantity_requested was added to borrow_requests, the walk-in RPC
-- was left alone on the reasoning that it would pick up the column's
-- `default 1` and keep working. It did keep working — but it also made a
-- walk-in for 25 chairs indistinguishable from one for a single chair,
-- so the capacity trigger under-counted every counter loan and staff had
-- no way to record what actually went out the door.
--
-- Dropped and recreated rather than CREATE OR REPLACE: adding a
-- parameter produces a new overload instead of replacing the old one,
-- and leaving the single-unit version callable would preserve the bug.
drop function if exists public.create_guest_borrow_request(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean
);

create function public.create_guest_borrow_request(
  item uuid,
  full_name text,
  address text,
  contact_number text,
  email text,
  purpose text,
  requested_from timestamptz,
  requested_to timestamptz,
  consented boolean,
  quantity integer default 1
)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  new_guest_id uuid;
  new_request_id uuid;
begin
  if not public.can_approve_item(item) then
    raise exception 'not authorized to create a walk-in request for this item';
  end if;
  if not consented then
    raise exception 'guest consent is required';
  end if;
  if quantity is null or quantity < 1 then
    raise exception 'quantity must be at least 1';
  end if;

  insert into guest_borrowers (full_name, address, contact_number, email, consented, consented_at, created_by)
  values (trim(full_name), trim(address), trim(contact_number), nullif(trim(coalesce(email, '')), ''), true, now(), auth.uid())
  returning id into new_guest_id;

  -- borrower_id defaults to auth.uid() at the column level (Phase 4) — it
  -- must be explicitly nulled here, or the xor check below would fail
  -- since the default silently fills in the calling staff member's id.
  --
  -- quantity_requested is checked against the item's free units by the
  -- existing capacity trigger, so an over-booked walk-in is rejected the
  -- same way a self-service request would be.
  insert into borrow_requests (
    item_id, borrower_id, guest_borrower_id, purpose,
    requested_from, requested_to, quantity_requested
  )
  values (item, null, new_guest_id, purpose, requested_from, requested_to, quantity)
  returning id into new_request_id;

  update borrow_requests set status = 'approved' where id = new_request_id;

  return new_request_id;
end;
$$;

revoke execute on function public.create_guest_borrow_request(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, integer
) from public, anon;
grant execute on function public.create_guest_borrow_request(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, integer
) to authenticated;
