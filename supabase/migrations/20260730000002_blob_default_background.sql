-- Blob is now the default background style for new profiles (was
-- glossy). Existing rows that never touched the setting keep whatever
-- they already have — there's no way to distinguish "explicitly chose
-- glossy" from "never changed it" without changing user data on their
-- behalf, so this only affects future signups.
alter table public.profiles
  alter column background_style set default 'blob';
