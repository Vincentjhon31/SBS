-- ============================================================
-- Live approvals: publish the tables the approvals surfaces read
-- ============================================================
-- Until now only public.notifications was replicated, so every other
-- screen was a snapshot — an approver on the phone photographing a
-- handoff wrote evidence that a colleague on the web dashboard could
-- only see by reloading the page.
--
-- Adding these tables to the realtime publication lets both surfaces
-- subscribe to postgres_changes and refetch on their own. The client
-- treats the events purely as "something changed, refetch"; the actual
-- reads still go through the normal RLS-guarded queries, so this widens
-- nothing a client could not already select.
--
-- RLS applies to the replicated payload as well, exactly as it does for
-- notifications: an approver only receives change events for rows their
-- policies already let them read.
--
-- `alter publication ... add table` has no `if not exists` and errors on
-- a table that is already a member, so membership is checked first —
-- this has to be safe to re-run against an environment where a table was
-- added by hand while debugging.
do $$
declare
  t text;
begin
  foreach t in array array[
    'borrow_requests',
    'borrow_evidence',
    -- Releasing/returning an item flips its availability, so the Items
    -- registry and the citizen Home carousel need the same nudge.
    'items'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    end if;
  end loop;
end $$;
