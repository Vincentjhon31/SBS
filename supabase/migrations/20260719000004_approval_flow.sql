-- Phase 5: Approval Flow
-- Approvers act on requests in their scope (their departments + the shared
-- pool). Status changes are guarded by a transition trigger; citizen
-- borrowers must have verified identity before their first approval.

-- ============================================================
-- Transition guard: the only legal status paths, with server-side
-- bookkeeping. approved_by/approved_at can never be spoofed by clients.
-- ============================================================
create or replace function public.guard_borrow_transition()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  borrower_kind text;
  citizen_verified boolean;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if (old.status, new.status) not in (
    ('pending', 'approved'),
    ('pending', 'rejected'),
    ('approved', 'released'),
    ('released', 'returned'),
    ('returned', 'closed'),
    ('approved', 'overdue'),
    ('released', 'overdue'),
    ('overdue', 'released'),
    ('overdue', 'returned')
  ) then
    raise exception 'invalid status transition: % -> %', old.status, new.status;
  end if;

  if old.status = 'pending' and new.status = 'approved' then
    select p.user_type into borrower_kind
    from profiles p where p.id = new.borrower_id;
    if borrower_kind = 'citizen' then
      select cp.verified into citizen_verified
      from citizen_profiles cp where cp.id = new.borrower_id;
      if not coalesce(citizen_verified, false) then
        raise exception 'citizen identity must be verified before approval';
      end if;
    end if;
    if auth.uid() is not null then
      new.approved_by := auth.uid();
    end if;
    new.approved_at := now();
    new.due_at := coalesce(new.due_at, new.requested_to);
  end if;

  if new.status = 'rejected'
     and length(trim(coalesce(new.rejected_reason, ''))) = 0 then
    raise exception 'rejection requires a reason';
  end if;

  if new.status = 'released' then
    new.released_at := coalesce(new.released_at, now());
  end if;
  if new.status = 'returned' then
    new.returned_at := coalesce(new.returned_at, now());
  end if;

  return new;
end;
$$;

create trigger borrow_request_transition_guard
before update on public.borrow_requests
for each row execute function public.guard_borrow_transition();

-- ============================================================
-- Approvers may update requests in their scope. Combined with the
-- transition trigger this yields: approve/reject now, release/return in
-- Phase 6, overdue flips in Phase 7.
-- ============================================================
create policy "approvers update scoped requests"
on public.borrow_requests for update
using (public.can_approve_item(item_id))
with check (public.can_approve_item(item_id));

grant update (status, rejected_reason, due_at)
  on public.borrow_requests to authenticated;

-- ============================================================
-- Citizen identity verification.
-- Staff can read citizen verification data; the verified flags are only
-- writable through this RPC (column grants keep them off-limits otherwise).
-- ============================================================
-- Approvers must see who they are approving.
create policy "staff read all profiles"
on public.profiles for select
using (public.is_staff());

create policy "staff read citizen profiles"
on public.citizen_profiles for select
using (public.is_staff());

create or replace function public.verify_citizen(citizen uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'only staff may verify citizen identity';
  end if;
  update citizen_profiles
  set verified = true, verified_by = auth.uid(), verified_at = now()
  where id = citizen;
  if not found then
    raise exception 'citizen profile not found';
  end if;
end;
$$;

revoke execute on function public.verify_citizen(uuid) from public, anon;
grant execute on function public.verify_citizen(uuid) to authenticated;

-- Staff must see the ID photo to verify it against the person.
create policy "staff read id photos"
on storage.objects for select to authenticated
using (bucket_id = 'id-photos' and public.is_staff());
