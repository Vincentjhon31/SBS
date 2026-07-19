-- Phase 4: Borrow Request Flow
-- State machine: pending -> approved -> released -> returned -> closed
--                pending -> rejected;  (approved|released) past due -> overdue
-- Double-booking is impossible at the database level: an exclusion
-- constraint rejects overlapping approved/released reservations even under
-- concurrent requests. Pending requests may overlap freely — the Approver
-- resolves conflicts by approving one and rejecting the others.

create extension if not exists btree_gist;

create table public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (id),
  borrower_id uuid not null references public.profiles (id) default auth.uid(),
  borrower_type text not null check (borrower_type in ('staff', 'citizen')),
  purpose text not null check (length(trim(purpose)) > 0),
  requested_from timestamptz not null,
  requested_to timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'released', 'returned', 'closed', 'overdue')),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  rejected_reason text,
  released_at timestamptz,
  returned_at timestamptz,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requested_to > requested_from)
);

create index borrow_requests_borrower_idx on public.borrow_requests (borrower_id);
create index borrow_requests_item_idx on public.borrow_requests (item_id);
create index borrow_requests_status_idx on public.borrow_requests (status);

-- The core guarantee of the system: two approved/released reservations can
-- never overlap on the same item. tstzrange defaults to [) bounds, so a
-- reservation ending exactly when another starts is NOT a conflict.
alter table public.borrow_requests
add constraint no_overlapping_approved_reservations
exclude using gist (
  item_id with =,
  tstzrange(requested_from, requested_to) with &&
) where (status in ('approved', 'released'));

-- ============================================================
-- Insert trigger: borrower_type always mirrors the borrower's profile and
-- a new request always starts pending — regardless of what a client sends.
-- ============================================================
create or replace function public.set_borrow_request_defaults()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  select user_type into new.borrower_type
  from profiles where id = new.borrower_id;
  if new.borrower_type is null then
    raise exception 'borrower has no profile';
  end if;
  new.status := 'pending';
  return new;
end;
$$;

create trigger borrow_request_defaults
before insert on public.borrow_requests
for each row execute function public.set_borrow_request_defaults();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger borrow_requests_touch_updated_at
before update on public.borrow_requests
for each row execute function public.touch_updated_at();

-- ============================================================
-- Approver visibility helper (guide's RLS sample): staff see requests for
-- unassigned items or items in a department they belong to.
-- ============================================================
create or replace function public.can_approve_item(item uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.is_staff() and exists (
    select 1 from items i
    where i.id = item
      and (
        i.owning_department_id is null
        or exists (
          select 1 from department_members dm
          where dm.user_id = auth.uid()
            and dm.department_id = i.owning_department_id
            and dm.role = 'approver'
        )
      )
  );
$$;

-- ============================================================
-- RLS — Phase 4 scope: borrowers create + read their own requests;
-- approvers read requests in their scope. Approve/reject/release/return
-- (updates) arrive with Phase 5.
-- ============================================================
alter table public.borrow_requests enable row level security;

create policy "borrowers read own requests"
on public.borrow_requests for select
using (borrower_id = auth.uid());

create policy "approvers read scoped requests"
on public.borrow_requests for select
using (public.can_approve_item(item_id));

create policy "borrowers create own requests"
on public.borrow_requests for insert
with check (
  borrower_id = auth.uid()
  and exists (select 1 from items i where i.id = item_id and i.active)
);

revoke all on public.borrow_requests from anon, authenticated;
grant select on public.borrow_requests to authenticated;
grant insert (item_id, borrower_id, borrower_type, purpose, requested_from, requested_to)
  on public.borrow_requests to authenticated;

-- ============================================================
-- Reserved windows RPC: lets any signed-in user see WHEN an item is
-- reserved (approved/released) without exposing WHO reserved it — used for
-- conflict warnings in the request form and the Phase 8 calendar.
-- ============================================================
create or replace function public.item_reserved_windows(item uuid)
returns table (reserved_from timestamptz, reserved_to timestamptz)
language sql stable security definer
set search_path = public
as $$
  select requested_from, requested_to
  from borrow_requests
  where item_id = item
    and status in ('approved', 'released')
    and requested_to >= now()
  order by requested_from;
$$;

revoke execute on function public.item_reserved_windows(uuid) from public, anon;
grant execute on function public.item_reserved_windows(uuid) to authenticated;
