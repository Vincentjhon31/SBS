-- Phase 2: Authentication schema
-- profiles (all users) + citizen_profiles (citizen verification data)
-- + private id-photos bucket, RLS on everything.

-- ============================================================
-- profiles — one row per auth user, created by trigger on signup.
-- Staff accounts are admin-provisioned (dashboard/Studio) with
-- raw_user_meta_data.user_type = 'staff'; app signups are citizens.
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  user_type text not null default 'citizen'
    check (user_type in ('staff', 'citizen')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "users read own profile"
on public.profiles for select
using (auth.uid() = id);

create policy "users update own profile"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Explicit grants (do not rely on default privileges): clients may read,
-- and update full_name only — user_type must never be self-editable.
-- Inserts happen via the security-definer trigger, never directly.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

-- ============================================================
-- citizen_profiles — verification data for citizen borrowers.
-- verified/verified_by/verified_at are set by Approvers (Phase 5);
-- citizens cannot write them (column-level grants below).
-- ============================================================
create table public.citizen_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  contact_number text not null,
  id_type text not null,
  id_number text not null,
  id_photo_path text,
  verified boolean not null default false,
  verified_by uuid references public.profiles (id),
  verified_at timestamptz,
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.citizen_profiles enable row level security;

create policy "citizens read own citizen profile"
on public.citizen_profiles for select
using (auth.uid() = id);

create policy "citizens create own citizen profile"
on public.citizen_profiles for insert
with check (auth.uid() = id);

create policy "citizens update own citizen profile"
on public.citizen_profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

revoke all on public.citizen_profiles from anon, authenticated;
grant select on public.citizen_profiles to authenticated;
grant insert (id, contact_number, id_type, id_number, id_photo_path)
  on public.citizen_profiles to authenticated;
grant update (contact_number, id_type, id_number, id_photo_path)
  on public.citizen_profiles to authenticated;

-- ============================================================
-- Signup trigger: auth.users -> public.profiles
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, user_type)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), new.email, 'Unnamed'),
    case
      when new.raw_user_meta_data ->> 'user_type' = 'staff' then 'staff'
      else 'citizen'
    end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================
-- Private storage bucket for citizen ID photos.
-- Objects live at <user_id>/... so ownership is derivable from the path.
-- Never public; reads via signed URLs or owner-scoped select.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('id-photos', 'id-photos', false)
on conflict (id) do nothing;

create policy "citizens upload own id photo"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'id-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "citizens read own id photo"
on storage.objects for select to authenticated
using (
  bucket_id = 'id-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "citizens replace own id photo"
on storage.objects for update to authenticated
using (
  bucket_id = 'id-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
