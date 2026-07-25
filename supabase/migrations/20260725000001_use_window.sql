-- Round 2: separate the "use / event" window from the availability window.
--
-- Until now requested_from/requested_to doubled as both "when the item is
-- out" and "when the borrower uses it". Citizens now distinguish them:
--   requested_from = PICKUP   (item leaves the LGU)
--   requested_to   = RETURN   (item comes back)
--   use_from/use_to = the EVENT window they actually use it for
--
-- Pickup may be the use-start day or up to one day earlier; return is on or
-- after the use-end. The availability window stays [pickup, return], so the
-- existing no-overlap exclusion constraint keeps preventing double-booking
-- with no change.
--
-- Both new columns are nullable: legacy rows and staff-witnessed walk-ins
-- (pickup = now, no advance planning) simply leave them NULL, and every
-- CHECK below is written to pass when they are NULL (SQL NULL comparisons
-- are never FALSE).
alter table public.borrow_requests
  add column use_from timestamptz,
  add column use_to timestamptz,
  -- Event window is ordered.
  add constraint use_window_ordered check (use_to >= use_from),
  -- Pickup is on or before the event starts.
  add constraint pickup_on_or_before_use check (requested_from <= use_from),
  -- Return is on or after the event ends.
  add constraint return_on_or_after_use check (requested_to >= use_to),
  -- Advance pickup is capped at one day before the event starts.
  add constraint advance_pickup_max_one_day
    check (use_from - requested_from <= interval '1 day');

-- Let self-service borrowers set the event window on insert (walk-ins go
-- through the security-definer RPC, which isn't bound by column grants).
grant insert (use_from, use_to) on public.borrow_requests to authenticated;
