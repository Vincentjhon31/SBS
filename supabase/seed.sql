-- LOCAL DEVELOPMENT SEED ONLY — never run against a production project.
-- Creates an admin-provisioned staff account:
--   email:    staff@lgu.local
--   password: StaffPass123!
-- The on_auth_user_created trigger creates the matching profiles row.

-- The empty-string token columns are required: GoTrue errors on NULLs there.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, phone_change, phone_change_token,
  reauthentication_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated',
  'authenticated',
  'staff@lgu.local',
  extensions.crypt('StaffPass123!', extensions.gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Test Staff", "user_type": "staff"}',
  now(),
  now(),
  '', '', '', '', '', '', '', ''
)
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
values (
  gen_random_uuid(),
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  '{"sub": "11111111-1111-1111-1111-111111111111", "email": "staff@lgu.local", "email_verified": true}',
  'email',
  now(),
  now(),
  now()
)
on conflict (provider_id, provider) do nothing;

-- Personal test staff account: vincentjhon1031@lgu.local / 123456789
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, phone_change, phone_change_token,
  reauthentication_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  'authenticated',
  'vincentjhon1031@lgu.local',
  extensions.crypt('123456789', extensions.gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Vincent Jhon", "user_type": "staff"}',
  now(),
  now(),
  '', '', '', '', '', '', '', ''
)
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
values (
  gen_random_uuid(),
  '44444444-4444-4444-4444-444444444444',
  '44444444-4444-4444-4444-444444444444',
  '{"sub": "44444444-4444-4444-4444-444444444444", "email": "vincentjhon1031@lgu.local", "email_verified": true}',
  'email',
  now(),
  now(),
  now()
)
on conflict (provider_id, provider) do nothing;

-- Vincent is the first superadmin (mirrors the hosted bootstrap in the
-- superadmin migration, which matches on this same full_name).
update public.profiles set is_superadmin = true
where id = '44444444-4444-4444-4444-444444444444';

-- Sample departments and a scoped membership so department behavior is
-- testable out of the box: Test Staff is an Approver for Motor Pool
-- (manages Motor Pool + unassigned items, but NOT General Services items).
insert into public.departments (id, name)
values
  ('22222222-2222-2222-2222-222222222222', 'Motor Pool'),
  ('33333333-3333-3333-3333-333333333333', 'General Services Office')
on conflict (id) do nothing;

insert into public.department_members (department_id, user_id)
values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
  -- Vincent Jhon is an approver for BOTH departments (full management reach).
  ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444')
on conflict (department_id, user_id) do nothing;

-- A few starter items so the registry isn't empty on first run.
insert into public.items (name, distinguishing_tag, category, owning_department_id, created_by)
values
  ('Multicab', 'SKA-1234', 'Vehicle', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
  ('Municipal Gymnasium', null, 'Venue', null, '11111111-1111-1111-1111-111111111111'),
  ('Sound System', 'Unit A', 'Equipment', null, '11111111-1111-1111-1111-111111111111'),
  -- GSO-owned: visible to all, manageable only by GSO approvers (Vincent).
  ('Stage Truss', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111')
on conflict do nothing;

-- The rest of the realistic LGU-borrowable registry. Duplicated here (with
-- hardcoded local UUIDs) rather than relying solely on migration
-- 20260723000003_lgu_items.sql's Vincent-anchored lookup, because
-- migrations run BEFORE this seed file during `db reset` — Vincent's
-- profile doesn't exist yet at that point locally, so the migration's
-- do-block would find nothing and skip. On hosted, Vincent's profile
-- already exists before the migration runs, so that copy handles it
-- there; `on conflict do nothing` on both sides keeps this idempotent
-- regardless of ordering.
insert into public.items (name, distinguishing_tag, category, owning_department_id, created_by)
values
  ('Ambulance', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Fire Truck', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Dump Truck', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Garbage Truck', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Passenger Van', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Service Patrol Vehicle', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Water Tanker Truck', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Backhoe', null, 'Vehicle', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444'),
  ('Multi-Purpose Hall', null, 'Venue', null, '44444444-4444-4444-4444-444444444444'),
  ('Barangay Covered Court', null, 'Venue', null, '44444444-4444-4444-4444-444444444444'),
  ('Municipal Session Hall', null, 'Venue', null, '44444444-4444-4444-4444-444444444444'),
  ('Municipal Plaza', null, 'Venue', null, '44444444-4444-4444-4444-444444444444'),
  ('Generator Set', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('LED Wall Screen', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Canopy Tent', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Foldable Tables', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Monobloc Chairs', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Stage Platform', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Stage Lighting Set', null, 'Equipment', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('LCD Projector', null, 'Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Videoke Machine', null, 'Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Public Address System', null, 'Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Chainsaw', null, 'Tool', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Grass Cutter', null, 'Tool', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Water Pump', null, 'Tool', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444'),
  ('Volleyball Set', null, 'Sports Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Basketball Set', null, 'Sports Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Badminton Set', null, 'Sports Equipment', null, '44444444-4444-4444-4444-444444444444'),
  ('Stretcher', null, 'Medical/Emergency', null, '44444444-4444-4444-4444-444444444444'),
  ('Wheelchair', null, 'Medical/Emergency', null, '44444444-4444-4444-4444-444444444444'),
  ('First Aid Kit', null, 'Medical/Emergency', null, '44444444-4444-4444-4444-444444444444')
on conflict do nothing;

-- flow_type defaults to 'borrow' on insert; the migration's own
-- Vehicle/Venue -> 'schedule' backfill only affects rows that already
-- existed when it ran, which (for the same before/after seed.sql
-- ordering reason as the comment above) is nothing on a fresh local
-- reset -- redo it here so local data matches what real hosted data
-- looks like after that backfill.
update public.items set flow_type = 'schedule' where category in ('Vehicle', 'Venue');
