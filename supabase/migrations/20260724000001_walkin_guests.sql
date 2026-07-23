-- Walk-in borrowing: a person with no app account, no login, borrowing
-- in person. Staff creates + witnesses the whole transaction at the
-- counter, so it reuses the existing evidence/release/return machinery
-- (Phase 6) almost entirely — the only new pieces are (1) an identity
-- that isn't backed by auth.users, and (2) letting the return date be
-- left open when staff and the guest genuinely don't know it yet.

create table public.guest_borrowers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) > 0),
  address text not null check (length(trim(address)) > 0),
  contact_number text not null check (length(trim(contact_number)) > 0),
  email text,
  -- DPA consent: the guest never taps anything themselves, so staff reads
  -- the notice aloud and confirms on their behalf at intake.
  consented boolean not null default false,
  consented_at timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.guest_borrowers enable row level security;

create policy "staff read guest borrowers"
on public.guest_borrowers for select
using (public.is_staff());

-- No insert/update grants: every write goes through
-- create_guest_borrow_request() below, which is security definer and
-- does its own authorization — a guest identity can never be forged by a
-- direct client write.
revoke all on public.guest_borrowers from anon, authenticated;
grant select on public.guest_borrowers to authenticated;

-- ============================================================
-- borrow_requests: allow a request to belong to a guest instead of a
-- profile, and allow an open-ended return date for guest loans only.
-- ============================================================
alter table public.borrow_requests
  alter column borrower_id drop not null,
  alter column requested_to drop not null,
  add column guest_borrower_id uuid references public.guest_borrowers (id),
  add constraint borrower_xor_guest check (
    (borrower_id is not null and guest_borrower_id is null)
    or (borrower_id is null and guest_borrower_id is not null)
  ),
  -- Self-service citizens/staff must still commit to a return date;
  -- only a staff-witnessed walk-in may leave it open. The original
  -- `requested_to > requested_from` check already passes on NULL
  -- (SQL NULL comparisons are non-FALSE), so it needs no change.
  add constraint requested_to_required_unless_guest check (
    requested_to is not null or borrower_type = 'guest'
  );

alter table public.borrow_requests
  drop constraint borrow_requests_borrower_type_check,
  add constraint borrow_requests_borrower_type_check
    check (borrower_type in ('staff', 'citizen', 'guest'));

-- Insert trigger: recognize the guest path instead of requiring a profile.
create or replace function public.set_borrow_request_defaults()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.guest_borrower_id is not null then
    new.borrower_type := 'guest';
  else
    select user_type into new.borrower_type
    from profiles where id = new.borrower_id;
    if new.borrower_type is null then
      raise exception 'borrower has no profile';
    end if;
  end if;
  new.status := 'pending';
  return new;
end;
$$;

-- An indefinite loan (requested_to null) must still block the item for
-- everyone else until it's returned — NULL >= now() is not true, so the
-- old filter silently hid open-ended windows from the conflict/calendar
-- view. This is the one behavioral fix needed for that to work.
create or replace function public.item_reserved_windows(item uuid)
returns table (reserved_from timestamptz, reserved_to timestamptz)
language sql stable security definer
set search_path = public
as $$
  select requested_from, requested_to
  from borrow_requests
  where item_id = item
    and status in ('approved', 'released')
    and (requested_to is null or requested_to >= now())
  order by requested_from;
$$;

-- ============================================================
-- create_guest_borrow_request: the walk-in counter flow in one atomic,
-- staff-authorized step — creates the guest, the request, and
-- immediately approves it (staff is physically present, so pending is a
-- real-if-instant transition rather than a separate wait). Evidence
-- capture (photos + liability ack) still happens as its own step right
-- after, through the existing release_item() RPC — unchanged.
-- ============================================================
create or replace function public.create_guest_borrow_request(
  item uuid,
  full_name text,
  address text,
  contact_number text,
  email text,
  purpose text,
  requested_from timestamptz,
  requested_to timestamptz,
  consented boolean
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

  insert into guest_borrowers (full_name, address, contact_number, email, consented, consented_at, created_by)
  values (trim(full_name), trim(address), trim(contact_number), nullif(trim(coalesce(email, '')), ''), true, now(), auth.uid())
  returning id into new_guest_id;

  -- borrower_id defaults to auth.uid() at the column level (Phase 4) — it
  -- must be explicitly nulled here, or the xor check below would fail
  -- since the default silently fills in the calling staff member's id.
  insert into borrow_requests (item_id, borrower_id, guest_borrower_id, purpose, requested_from, requested_to)
  values (item, null, new_guest_id, purpose, requested_from, requested_to)
  returning id into new_request_id;

  update borrow_requests set status = 'approved' where id = new_request_id;

  return new_request_id;
end;
$$;

revoke execute on function public.create_guest_borrow_request(uuid, text, text, text, text, text, timestamptz, timestamptz, boolean) from public, anon;
grant execute on function public.create_guest_borrow_request(uuid, text, text, text, text, text, timestamptz, timestamptz, boolean) to authenticated;

-- ============================================================
-- Phase 7's notification triggers assumed borrower_id was always
-- present. A guest has no account and therefore no in-app inbox to
-- notify — skip the borrower-facing insert for guest rows (staff still
-- gets the approver-facing overdue alert, now naming the guest correctly
-- instead of a blank borrower).
-- ============================================================
create or replace function public.notify_request_decision()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  label text;
begin
  if new.status = old.status then
    return new;
  end if;
  if new.borrower_id is null then
    return new; -- guest: no account to notify in-app
  end if;
  label := public.item_label(new.item_id);

  if new.status = 'approved' then
    insert into notifications (recipient_id, borrow_request_id, type, title, body)
    values (
      new.borrower_id, new.id, 'request_approved',
      'Request approved',
      format('Your request for %s (%s to %s) was approved. Due back %s.',
        label,
        to_char(new.requested_from, 'Mon DD HH24:MI'),
        to_char(new.requested_to, 'Mon DD HH24:MI'),
        to_char(new.due_at, 'Mon DD HH24:MI'))
    );
  elsif new.status = 'rejected' then
    insert into notifications (recipient_id, borrow_request_id, type, title, body)
    values (
      new.borrower_id, new.id, 'request_rejected',
      'Request rejected',
      format('Your request for %s was rejected: %s', label, new.rejected_reason)
    );
  end if;
  return new;
end;
$$;

create or replace function public.run_due_checks()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  r record;
  approver uuid;
  label text;
  borrower_label text;
begin
  -- Due-soon: released (or approved-but-uncollected) items due within 24h.
  for r in
    select br.* from borrow_requests br
    where br.status in ('approved', 'released')
      and br.due_at between now() and now() + interval '24 hours'
      and not exists (
        select 1 from notifications n
        where n.borrow_request_id = br.id and n.type = 'due_soon'
      )
  loop
    if r.borrower_id is not null then
      label := public.item_label(r.item_id);
      insert into notifications (recipient_id, borrow_request_id, type, title, body)
      values (
        r.borrower_id, r.id, 'due_soon',
        'Return due soon',
        format('%s is due back on %s.', label, to_char(r.due_at, 'Mon DD HH24:MI'))
      );
    end if;
  end loop;

  -- Overdue: flip status, then notify the borrower (if they have an
  -- account) AND the item's approvers (always — including guest loans).
  for r in
    update borrow_requests br
    set status = 'overdue'
    where br.status in ('approved', 'released')
      and br.due_at < now()
    returning br.*
  loop
    label := public.item_label(r.item_id);
    if r.borrower_id is not null then
      insert into notifications (recipient_id, borrow_request_id, type, title, body)
      values (
        r.borrower_id, r.id, 'overdue',
        'Item overdue',
        format('%s was due on %s and has not been returned. Please return it '
               'as soon as possible.', label, to_char(r.due_at, 'Mon DD HH24:MI'))
      );
    end if;
    borrower_label := coalesce(
      (select full_name from profiles where id = r.borrower_id),
      (select full_name from guest_borrowers where id = r.guest_borrower_id),
      'a walk-in borrower'
    );
    for approver in select public.item_approver_ids(r.item_id)
    loop
      insert into notifications (recipient_id, borrow_request_id, type, title, body)
      values (
        approver, r.id, 'overdue',
        'Borrowed item overdue',
        format('%s (borrowed by %s) was due on %s and is not yet returned.',
          label, borrower_label, to_char(r.due_at, 'Mon DD HH24:MI'))
      );
    end loop;
  end loop;
end;
$$;

revoke execute on function public.run_due_checks() from public, anon, authenticated;
