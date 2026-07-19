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

-- Sample departments and a scoped membership so department behavior is
-- testable out of the box: Test Staff is an Approver for Motor Pool
-- (manages Motor Pool + unassigned items, but NOT General Services items).
insert into public.departments (id, name)
values
  ('22222222-2222-2222-2222-222222222222', 'Motor Pool'),
  ('33333333-3333-3333-3333-333333333333', 'General Services Office')
on conflict (id) do nothing;

insert into public.department_members (department_id, user_id)
values ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111')
on conflict (department_id, user_id) do nothing;

-- A few starter items so the registry isn't empty on first run.
insert into public.items (name, distinguishing_tag, category, owning_department_id, created_by)
values
  ('Multicab', 'SKA-1234', 'Vehicle', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111'),
  ('Municipal Gymnasium', null, 'Venue', null, '11111111-1111-1111-1111-111111111111'),
  ('Sound System', 'Unit A', 'Equipment', null, '11111111-1111-1111-1111-111111111111');
