-- Phase 9: Settings & Data Policy
-- Consent is already captured at citizen registration (citizen_profiles.
-- consented_at, Phase 2). This phase adds: a scheduled photo-retention
-- purge (Philippine Data Privacy Act — photos are not kept indefinitely),
-- a self-service data export, and a staff-handled deletion request flow
-- that anonymizes personal identifiers while preserving the transactional
-- record the whole system exists to keep (see Evidence module rationale).

-- ============================================================
-- Photo columns become nullable so retention purge can clear them while
-- keeping the evidence ROW (and its condition notes) as the audit record.
-- ============================================================
alter table public.borrow_evidence
  alter column borrower_photo_path drop not null,
  alter column item_photo_path drop not null,
  add column purged_at timestamptz;

-- ============================================================
-- Data deletion requests — citizens ask, staff fulfill (anonymize).
-- Not a self-serve hard delete: an active/recent borrower's transaction
-- history is an LGU accountability record, not disposable on demand.
-- ============================================================
create table public.data_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  reason text,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  completed_by uuid references public.profiles (id)
);

-- Only one open request at a time per user.
create unique index data_deletion_requests_one_pending
  on public.data_deletion_requests (user_id) where (status = 'pending');

alter table public.data_deletion_requests enable row level security;

create policy "users read own deletion requests"
on public.data_deletion_requests for select
using (user_id = auth.uid());

create policy "users create own deletion request"
on public.data_deletion_requests for insert
with check (user_id = auth.uid());

create policy "staff read all deletion requests"
on public.data_deletion_requests for select
using (public.is_staff());

revoke all on public.data_deletion_requests from anon, authenticated;
grant select on public.data_deletion_requests to authenticated;
grant insert (user_id, reason) on public.data_deletion_requests to authenticated;
-- status/completed_* are set only via complete_deletion_request() below.

-- ============================================================
-- Self-service export: everything the app holds about the caller.
-- ============================================================
create or replace function public.export_my_data()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile', (select to_jsonb(p) from profiles p where p.id = auth.uid()),
    'citizen_profile', (
      select to_jsonb(cp) - 'id_photo_path' || jsonb_build_object('has_id_photo', cp.id_photo_path is not null)
      from citizen_profiles cp where cp.id = auth.uid()
    ),
    'borrow_requests', coalesce((
      select jsonb_agg(to_jsonb(br) order by br.created_at)
      from borrow_requests br where br.borrower_id = auth.uid()
    ), '[]'::jsonb),
    'evidence', coalesce((
      select jsonb_agg(jsonb_build_object(
        'borrow_request_id', be.borrow_request_id,
        'stage', be.stage,
        'condition_notes', be.condition_notes,
        'captured_at', be.captured_at,
        'photos_available', be.purged_at is null
      ))
      from borrow_evidence be
      join borrow_requests br on br.id = be.borrow_request_id
      where br.borrower_id = auth.uid()
    ), '[]'::jsonb),
    'liability_acknowledgments', coalesce((
      select jsonb_agg(to_jsonb(la))
      from liability_acknowledgments la
      join borrow_requests br on br.id = la.borrow_request_id
      where br.borrower_id = auth.uid()
    ), '[]'::jsonb),
    'notifications', coalesce((
      select jsonb_agg(to_jsonb(n) order by n.sent_at)
      from notifications n where n.recipient_id = auth.uid()
    ), '[]'::jsonb),
    'exported_at', now()
  );
$$;

revoke execute on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- ============================================================
-- Fulfilling a deletion request: staff-only, anonymizes PII, deletes the
-- ID photo object, keeps the transactional record (accountability trail).
-- ============================================================
create or replace function public.complete_deletion_request(request_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  target_user uuid;
  photo_path text;
begin
  if not public.is_staff() then
    raise exception 'only staff may complete deletion requests';
  end if;

  select user_id into target_user
  from data_deletion_requests where id = request_id and status = 'pending';
  if target_user is null then
    raise exception 'no pending deletion request with that id';
  end if;

  update profiles set full_name = 'Deleted User' where id = target_user;

  -- storage.objects blocks raw SQL deletes (protect_delete trigger) to
  -- avoid orphaning physical files — real object removal requires the
  -- Storage API. Nulling the path here still fully revokes app access:
  -- no signed URL can be generated without it, and our storage RLS scopes
  -- reads to exactly the path this column holds. Physical bucket cleanup
  -- is a deferred follow-up (a Storage-API-based sweep), same posture as
  -- the FCM push channel deferred in Phase 7.
  update citizen_profiles
  set contact_number = 'REDACTED', id_number = 'REDACTED', id_photo_path = null
  where id = target_user;

  update data_deletion_requests
  set status = 'completed', completed_at = now(), completed_by = auth.uid()
  where id = request_id;
end;
$$;

revoke execute on function public.complete_deletion_request(uuid) from public, anon;
grant execute on function public.complete_deletion_request(uuid) to authenticated;

-- ============================================================
-- Scheduled photo retention purge. Default 365 days (guide range: 6-12
-- months) — hardcoded for v1, consistent with the due-soon reminder's
-- fixed 24h window. Evidence rows and condition notes are kept
-- indefinitely as the accountability record; only the photo REFERENCES
-- go, which fully revokes app-level access (see complete_deletion_request
-- comment above re: storage.objects' protect_delete trigger — physical
-- bucket cleanup is a deferred Storage-API-based follow-up).
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
  set borrower_photo_path = null, item_photo_path = null, purged_at = now()
  where captured_at < now() - retention
    and purged_at is null;

  -- Citizen ID photos: purge once the citizen has had no borrowing
  -- activity for the retention window (registration date if they never
  -- borrowed at all).
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

create extension if not exists pg_cron;
select cron.schedule('sbs-photo-retention', '0 3 * * *',
  'select public.run_photo_retention()');
