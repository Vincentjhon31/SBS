-- Merges the release/return "borrower photo" + "item photo" pair into one
-- undifferentiated set of up to 5 photos (e.g. the borrower photographed
-- holding the item together) -- staff no longer need two separate rigid
-- exposures, just enough photos to show the handoff/return clearly.

alter table public.borrow_evidence
  add column photo_paths text[] not null default '{}';

-- Preserve existing release/return evidence as 2-element arrays before the
-- old columns are dropped.
update public.borrow_evidence
set photo_paths = array_remove(array[borrower_photo_path, item_photo_path], null);

-- Only an upper bound at the table level -- the "at least 1" rule is
-- enforced by release_item/return_item at capture time, but the photo
-- retention purge (run_photo_retention) legitimately clears photo_paths
-- back to '{}' after the retention window, which a lower bound would block.
alter table public.borrow_evidence
  add constraint borrow_evidence_photo_count
    check (cardinality(photo_paths) <= 5);

alter table public.borrow_evidence
  drop column borrower_photo_path,
  drop column item_photo_path;

-- ============================================================
-- release_item / return_item: photos become a single array param instead
-- of two scalar text params. The parameter list changed shape, so the old
-- overload must be dropped explicitly -- CREATE OR REPLACE can't do this.
-- ============================================================
drop function public.release_item(uuid, text, text, boolean, text, text);
drop function public.return_item(uuid, text, text, text);

create or replace function public.release_item(
  req uuid,
  photos text[],
  acknowledged boolean,
  terms_version text,
  notes text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  target record;
begin
  select * into target from borrow_requests where id = req;
  if target is null or not public.can_approve_item(target.item_id) then
    raise exception 'request not found or outside your approval scope';
  end if;
  if target.status <> 'approved' then
    raise exception 'only an approved request can be released (current: %)', target.status;
  end if;
  if not acknowledged then
    raise exception 'liability acknowledgment is required at release';
  end if;
  if photos is null or cardinality(photos) < 1 or cardinality(photos) > 5 then
    raise exception 'between 1 and 5 photos are required';
  end if;

  insert into borrow_evidence
    (borrow_request_id, stage, photo_paths, condition_notes, captured_by)
  values (req, 'release', photos, notes, auth.uid());

  insert into liability_acknowledgments (borrow_request_id, acknowledged, terms_version)
  values (req, true, terms_version);

  update borrow_requests set status = 'released' where id = req;
end;
$$;

create or replace function public.return_item(
  req uuid,
  photos text[],
  notes text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  target record;
begin
  select * into target from borrow_requests where id = req;
  if target is null or not public.can_approve_item(target.item_id) then
    raise exception 'request not found or outside your approval scope';
  end if;
  if target.status not in ('released', 'overdue') then
    raise exception 'only a released or overdue request can be returned (current: %)', target.status;
  end if;
  if photos is null or cardinality(photos) < 1 or cardinality(photos) > 5 then
    raise exception 'between 1 and 5 photos are required';
  end if;

  insert into borrow_evidence
    (borrow_request_id, stage, photo_paths, condition_notes, captured_by)
  values (req, 'return', photos, notes, auth.uid());

  update borrow_requests set status = 'returned' where id = req;
end;
$$;

revoke execute on function public.release_item(uuid, text[], boolean, text, text) from public, anon;
grant execute on function public.release_item(uuid, text[], boolean, text, text) to authenticated;
revoke execute on function public.return_item(uuid, text[], text) from public, anon;
grant execute on function public.return_item(uuid, text[], text) to authenticated;

-- ============================================================
-- run_photo_retention referenced the two dropped columns -- point it at
-- photo_paths instead (same behavior: clear the array, stamp purged_at).
-- ============================================================
create or replace function public.run_photo_retention()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  retention interval := interval '365 days';
begin
  update borrow_evidence
  set photo_paths = '{}', purged_at = now()
  where captured_at < now() - retention
    and purged_at is null;

  update citizen_profiles cp
  set id_photo_path = null
  where cp.id_photo_path is not null
    and coalesce(
          (select max(br.created_at) from borrow_requests br where br.borrower_id = cp.id),
          cp.created_at
        ) < now() - retention;
end;
$$;

revoke execute on function public.run_photo_retention() from public, anon, authenticated;
