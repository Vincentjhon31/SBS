-- Background style preference: now a real per-account setting (like
-- theme_color), persisted server-side so it follows the user across
-- devices instead of only living in SharedPreferences on one device.
alter table public.profiles
  add column background_style text not null default 'glossy'
    check (background_style in ('glossy', 'blob', 'solid'));

grant update (background_style) on public.profiles to authenticated;

-- Broaden the accent color palette (teal/coral/green) to match the new
-- colorful redesign — drop and recreate the CHECK rather than alter it,
-- Postgres has no direct "alter check" syntax.
alter table public.profiles
  drop constraint profiles_theme_color_check;

alter table public.profiles
  add constraint profiles_theme_color_check
    check (theme_color in ('blue', 'purple', 'teal', 'coral', 'green'));
