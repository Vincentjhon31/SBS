-- Phase 3: Items Registry
-- Lightweight, self-growing registry — deliberately NOT an inventory:
-- no stock counts, no SKUs, no forced categories. Department ownership is
-- nullable; unassigned items form a shared LGU-wide pool.

-- ============================================================
-- departments — optional ownership scoping, used only when needed.
-- ============================================================
create table public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index departments_name_unique on public.departments (lower(name));

-- ============================================================
-- department_members — marks staff as Approvers for a department.
-- Managed via Studio/admin for now (no client write path).
-- ============================================================
create table public.department_members (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'approver' check (role = 'approver'),
  joined_at timestamptz not null default now(),
  unique (department_id, user_id)
);

-- ============================================================
-- items — name + optional distinguishing tag is the whole identity.
-- ============================================================
create table public.items (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  distinguishing_tag text,
  category text,
  owning_department_id uuid references public.departments (id),
  reference_photo_path text,
  active boolean not null default true,
  created_by uuid not null references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now()
);

-- "Multicab" and "multicab" must not become two items; the tag tells
-- "Van 1" from "Van 2".
create unique index items_name_tag_unique
  on public.items (lower(trim(name)), lower(coalesce(trim(distinguishing_tag), '')));

-- ============================================================
-- Helper functions (security definer so policies don't depend on the
-- caller's visibility into profiles/department_members).
-- ============================================================
create or replace function public.is_staff()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and user_type = 'staff'
  );
$$;

-- Guide rule: staff scoped to a department manage that department's items
-- plus the unassigned pool; unscoped staff manage unassigned items only.
create or replace function public.can_manage_item_dept(dept uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.is_staff() and (
    dept is null
    or exists (
      select 1 from department_members dm
      where dm.user_id = auth.uid()
        and dm.department_id = dept
        and dm.role = 'approver'
    )
  );
$$;

-- ============================================================
-- RLS
-- ============================================================
alter table public.departments enable row level security;
alter table public.department_members enable row level security;
alter table public.items enable row level security;

-- Everyone signed in can browse departments and items (borrowers need to
-- search the registry to request).
create policy "authenticated read departments"
on public.departments for select
using (true);

create policy "staff manage departments"
on public.departments for insert
with check (public.is_staff());

create policy "staff update departments"
on public.departments for update
using (public.is_staff())
with check (public.is_staff());

create policy "read own memberships or staff"
on public.department_members for select
using (user_id = auth.uid() or public.is_staff());

create policy "authenticated read items"
on public.items for select
using (true);

-- Self-growing registry: any signed-in user may add an item (the guide's
-- "requester or approver just types its name"), but only into the
-- unassigned pool unless they can manage the target department.
create policy "authenticated create items"
on public.items for insert
with check (
  created_by = auth.uid()
  and (
    owning_department_id is null
    or public.can_manage_item_dept(owning_department_id)
  )
);

create policy "scoped staff update items"
on public.items for update
using (public.can_manage_item_dept(owning_department_id))
with check (public.can_manage_item_dept(owning_department_id));

-- Explicit grants (default privileges don't apply to app roles locally).
revoke all on public.departments from anon, authenticated;
grant select on public.departments to authenticated;
grant insert (name) on public.departments to authenticated;
grant update (name, active) on public.departments to authenticated;

revoke all on public.department_members from anon, authenticated;
grant select on public.department_members to authenticated;

revoke all on public.items from anon, authenticated;
grant select on public.items to authenticated;
grant insert (name, distinguishing_tag, category, owning_department_id, reference_photo_path, created_by)
  on public.items to authenticated;
grant update (name, distinguishing_tag, category, owning_department_id, reference_photo_path, active)
  on public.items to authenticated;

-- ============================================================
-- Reference photos: private bucket, staff-write, any-authenticated read
-- (item photos identify the item to all users; they are not sensitive
-- personal data, but stay non-public per the blanket storage rule).
-- ============================================================
insert into storage.buckets (id, name, public)
values ('item-photos', 'item-photos', false)
on conflict (id) do nothing;

create policy "staff upload item photos"
on storage.objects for insert to authenticated
with check (bucket_id = 'item-photos' and public.is_staff());

create policy "staff replace item photos"
on storage.objects for update to authenticated
using (bucket_id = 'item-photos' and public.is_staff());

create policy "authenticated read item photos"
on storage.objects for select to authenticated
using (bucket_id = 'item-photos');
