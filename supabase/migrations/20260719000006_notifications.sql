-- Phase 7: Notifications
-- A due date sitting in a database does nothing on its own. This makes it
-- active: instant notifications on approve/reject, and a pg_cron job that
-- flips overdue statuses and sends due-soon / overdue notices.
-- Delivery channel v1 is in-app (realtime stream); the same rows become
-- the source for FCM push once Firebase credentials exist.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  borrow_request_id uuid references public.borrow_requests (id) on delete cascade,
  type text not null
    check (type in ('request_approved', 'request_rejected', 'due_soon', 'overdue')),
  title text not null,
  body text not null,
  channel text not null default 'in_app' check (channel in ('in_app', 'push')),
  read_at timestamptz,
  sent_at timestamptz not null default now()
);

create index notifications_recipient_idx
  on public.notifications (recipient_id, sent_at desc);

alter table public.notifications enable row level security;

create policy "recipients read own notifications"
on public.notifications for select
using (recipient_id = auth.uid());

create policy "recipients mark own notifications read"
on public.notifications for update
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

-- Clients may only flip read_at; rows are created by triggers/jobs.
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Realtime stream for the in-app inbox (RLS applies to the stream too).
alter publication supabase_realtime add table public.notifications;

-- ============================================================
-- Helpers
-- ============================================================
create or replace function public.item_label(item uuid)
returns text
language sql stable
set search_path = public
as $$
  select i.name || coalesce(' (' || i.distinguishing_tag || ')', '')
  from items i where i.id = item;
$$;

-- Approvers responsible for an item: its department's members, or every
-- staff member for shared-pool items.
create or replace function public.item_approver_ids(item uuid)
returns setof uuid
language sql stable
set search_path = public
as $$
  select dm.user_id
  from items i
  join department_members dm on dm.department_id = i.owning_department_id
  where i.id = item
  union
  select p.id
  from items i, profiles p
  where i.id = item
    and i.owning_department_id is null
    and p.user_type = 'staff';
$$;

-- ============================================================
-- Instant notifications on approve / reject.
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

create trigger borrow_request_decision_notify
after update on public.borrow_requests
for each row execute function public.notify_request_decision();

-- ============================================================
-- Scheduled checks: due-soon reminders and the overdue flip.
-- Runs via pg_cron; safe to run any number of times (idempotent).
-- ============================================================
create or replace function public.run_due_checks()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  r record;
  approver uuid;
  label text;
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
    label := public.item_label(r.item_id);
    insert into notifications (recipient_id, borrow_request_id, type, title, body)
    values (
      r.borrower_id, r.id, 'due_soon',
      'Return due soon',
      format('%s is due back on %s.', label, to_char(r.due_at, 'Mon DD HH24:MI'))
    );
  end loop;

  -- Overdue: flip status, then notify borrower AND the item's approvers.
  for r in
    update borrow_requests br
    set status = 'overdue'
    where br.status in ('approved', 'released')
      and br.due_at < now()
    returning br.*
  loop
    label := public.item_label(r.item_id);
    insert into notifications (recipient_id, borrow_request_id, type, title, body)
    values (
      r.borrower_id, r.id, 'overdue',
      'Item overdue',
      format('%s was due on %s and has not been returned. Please return it '
             'as soon as possible.', label, to_char(r.due_at, 'Mon DD HH24:MI'))
    );
    for approver in select public.item_approver_ids(r.item_id)
    loop
      insert into notifications (recipient_id, borrow_request_id, type, title, body)
      values (
        approver, r.id, 'overdue',
        'Borrowed item overdue',
        format('%s (borrowed by %s) was due on %s and is not yet returned.',
          label,
          (select full_name from profiles where id = r.borrower_id),
          to_char(r.due_at, 'Mon DD HH24:MI'))
      );
    end loop;
  end loop;
end;
$$;

-- Maintenance/internal functions are not client-callable (pg_cron runs as
-- postgres and is unaffected; item_label stays callable by signed-in users
-- since items are readable anyway).
revoke execute on function public.run_due_checks() from public, anon, authenticated;
revoke execute on function public.item_approver_ids(uuid) from public, anon, authenticated;
revoke execute on function public.item_label(uuid) from public, anon;

-- Every 15 minutes. pg_cron ships preloaded in Supabase Postgres.
create extension if not exists pg_cron;
select cron.schedule('sbs-due-checks', '*/15 * * * *',
  'select public.run_due_checks()');
