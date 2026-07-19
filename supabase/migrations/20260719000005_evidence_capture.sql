-- Phase 6: Evidence & Accountability
-- Every completed transaction gets TWO evidence records — one at release,
-- one at return — each with a borrower photo and an item photo. This is
-- what answers "was it damaged before or after I had it". Release also
-- captures a versioned liability acknowledgment.

create table public.borrow_evidence (
  id uuid primary key default gen_random_uuid(),
  borrow_request_id uuid not null references public.borrow_requests (id) on delete cascade,
  stage text not null check (stage in ('release', 'return')),
  borrower_photo_path text not null,
  item_photo_path text not null,
  condition_notes text,
  captured_by uuid not null references public.profiles (id),
  captured_at timestamptz not null default now(),
  unique (borrow_request_id, stage)
);

create table public.liability_acknowledgments (
  id uuid primary key default gen_random_uuid(),
  borrow_request_id uuid not null unique references public.borrow_requests (id) on delete cascade,
  acknowledged boolean not null,
  acknowledged_at timestamptz not null default now(),
  terms_version text not null
);

-- ============================================================
-- Visibility: the borrower of the request, or an approver in scope.
-- ============================================================
create or replace function public.can_view_request(req uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from borrow_requests br
    where br.id = req
      and (br.borrower_id = auth.uid() or public.can_approve_item(br.item_id))
  );
$$;

alter table public.borrow_evidence enable row level security;
alter table public.liability_acknowledgments enable row level security;

create policy "request parties read evidence"
on public.borrow_evidence for select
using (public.can_view_request(borrow_request_id));

create policy "request parties read acknowledgments"
on public.liability_acknowledgments for select
using (public.can_view_request(borrow_request_id));

-- Writes happen ONLY through the RPCs below (security definer); clients
-- get read-only access.
revoke all on public.borrow_evidence from anon, authenticated;
grant select on public.borrow_evidence to authenticated;
revoke all on public.liability_acknowledgments from anon, authenticated;
grant select on public.liability_acknowledgments to authenticated;

-- ============================================================
-- Evidence photo storage: private bucket, objects live under
-- <request_id>/<stage>_<kind>.jpg. Approvers in scope write; the
-- borrower and scoped approvers read.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('evidence-photos', 'evidence-photos', false)
on conflict (id) do nothing;

create or replace function public.can_capture_evidence_object(object_name text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from borrow_requests br
    where br.id::text = (storage.foldername(object_name))[1]
      and public.can_approve_item(br.item_id)
  );
$$;

create or replace function public.can_view_evidence_object(object_name text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from borrow_requests br
    where br.id::text = (storage.foldername(object_name))[1]
      and (br.borrower_id = auth.uid() or public.can_approve_item(br.item_id))
  );
$$;

create policy "approvers capture evidence photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'evidence-photos'
  and public.can_capture_evidence_object(name)
);

create policy "request parties view evidence photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'evidence-photos'
  and public.can_view_evidence_object(name)
);

-- ============================================================
-- release_item: the atomic handoff. Requires an approved request in the
-- caller's scope, both photos, and a positive liability acknowledgment.
-- ============================================================
create or replace function public.release_item(
  req uuid,
  borrower_photo text,
  item_photo text,
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
  if coalesce(trim(borrower_photo), '') = '' or coalesce(trim(item_photo), '') = '' then
    raise exception 'both borrower and item photos are required';
  end if;

  insert into borrow_evidence
    (borrow_request_id, stage, borrower_photo_path, item_photo_path, condition_notes, captured_by)
  values (req, 'release', borrower_photo, item_photo, notes, auth.uid());

  insert into liability_acknowledgments (borrow_request_id, acknowledged, terms_version)
  values (req, true, terms_version);

  update borrow_requests set status = 'released' where id = req;
end;
$$;

-- ============================================================
-- return_item: closes the evidence loop. Works from released or overdue.
-- ============================================================
create or replace function public.return_item(
  req uuid,
  borrower_photo text,
  item_photo text,
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
  if coalesce(trim(borrower_photo), '') = '' or coalesce(trim(item_photo), '') = '' then
    raise exception 'both borrower and item photos are required';
  end if;

  insert into borrow_evidence
    (borrow_request_id, stage, borrower_photo_path, item_photo_path, condition_notes, captured_by)
  values (req, 'return', borrower_photo, item_photo, notes, auth.uid());

  update borrow_requests set status = 'returned' where id = req;
end;
$$;

revoke execute on function public.release_item(uuid, text, text, boolean, text, text) from public, anon;
grant execute on function public.release_item(uuid, text, text, boolean, text, text) to authenticated;
revoke execute on function public.return_item(uuid, text, text, text) from public, anon;
grant execute on function public.return_item(uuid, text, text, text) to authenticated;
