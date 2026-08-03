-- Light/dark choice follows the account, and defaults to light.
--
-- theme_color and background_style were already synced to the profile, so
-- an accent and backdrop chosen on one device showed up on the next. The
-- light/dark mode was not — it lived only in the device's
-- SharedPreferences, defaulting to ThemeMode.system. Signing in anywhere
-- new therefore inherited whatever the operating system was set to rather
-- than what the user had picked, which read as the app forgetting the
-- setting every time.
--
-- Default is 'light' rather than 'system': this is a daytime counter tool
-- for LGU staff and residents, and following a phone's night schedule into
-- dark mode is a surprise rather than a feature. Dark is still one tap
-- away in Settings.
alter table public.profiles
  add column theme_mode text not null default 'light'
    check (theme_mode in ('light', 'dark', 'system'));

grant update (theme_mode) on public.profiles to authenticated;
