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
