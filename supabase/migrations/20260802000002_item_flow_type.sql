-- Splits the registry into two flows: "borrow" (equipment/tools taken
-- away and returned) and "schedule" (venues/vehicles reserved for use).
-- Explicit per-item field rather than inferring from the free-text
-- category, since category has no fixed taxonomy and staff can type
-- anything -- this keeps the split correct even for categories that
-- don't exist yet.

alter table public.items
  add column flow_type text not null default 'borrow'
    check (flow_type in ('borrow', 'schedule'));

-- One-time sensible backfill for the already-seeded catalog; staff can
-- recategorize any item afterward via the item form.
update public.items
set flow_type = 'schedule'
where category in ('Vehicle', 'Venue');

grant insert (flow_type) on public.items to authenticated;
grant update (flow_type) on public.items to authenticated;
