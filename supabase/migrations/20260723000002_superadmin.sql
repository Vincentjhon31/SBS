-- Superadmin: a cross-department oversight tier layered on top of staff,
-- not a third user_type (keeps existing Approver/RLS logic untouched).
-- Full oversight bundle: see/act on every request regardless of
-- department scoping, manage department_members (staff assignments —
-- previously had no write path at all), and view aggregate stats.
-- Deletion-request handling is already staff-wide (Phase 9) — no change
-- needed there, just surfaced in the new dashboard.

alter table public.profiles
  add column is_superadmin boolean not null default false;

create or replace function public.is_superadmin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce((select p.is_superadmin from profiles p where p.id = auth.uid()), false);
$$;

-- ============================================================
-- Cross-department request visibility + action, additive to the
-- existing department-scoped approver policies (permissive OR).
-- ============================================================
create policy "superadmins read all requests"
on public.borrow_requests for select
using (public.is_superadmin());

create policy "superadmins update all requests"
on public.borrow_requests for update
using (public.is_superadmin())
with check (public.is_superadmin());

-- ============================================================
-- department_members had SELECT only (Phase 3) — no one could actually
-- assign staff to a department through the app. Superadmin gets that.
-- ============================================================
create policy "superadmins manage department members"
on public.department_members for all
using (public.is_superadmin())
with check (public.is_superadmin());

grant insert (department_id, user_id, role) on public.department_members to authenticated;
grant delete on public.department_members to authenticated;

-- ============================================================
-- Aggregate stats — superadmin-only.
-- ============================================================
create or replace function public.superadmin_stats()
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.is_superadmin() then
    raise exception 'only superadmins may view stats';
  end if;

  return jsonb_build_object(
    'total_items', (select count(*) from items where active),
    'total_departments', (select count(*) from departments where active),
    'total_staff', (select count(*) from profiles where user_type = 'staff'),
    'total_citizens', (select count(*) from profiles where user_type = 'citizen'),
    'verified_citizens', (select count(*) from citizen_profiles where verified),
    'unverified_citizens', (select count(*) from citizen_profiles where not verified),
    'pending_requests', (select count(*) from borrow_requests where status = 'pending'),
    'active_loans', (select count(*) from borrow_requests where status in ('approved', 'released')),
    'overdue_requests', (select count(*) from borrow_requests where status = 'overdue'),
    'pending_deletion_requests', (select count(*) from data_deletion_requests where status = 'pending')
  );
end;
$$;

revoke execute on function public.superadmin_stats() from public, anon;
grant execute on function public.superadmin_stats() to authenticated;

-- The very first superadmin — bootstrapped the same way the first staff
-- account was (a named, known account; see supabase/seed.sql for the
-- local-dev equivalent).
update public.profiles set is_superadmin = true where full_name = 'Vincent Jhon';
