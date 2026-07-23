-- Accent color preference: a real per-account setting (blue/purple),
-- persisted server-side so it follows the user across devices — distinct
-- from ThemeMode (light/dark/system), which stays a local device setting.

alter table public.profiles
  add column theme_color text not null default 'blue'
    check (theme_color in ('blue', 'purple'));

-- RLS already scopes updates to the caller's own row (Phase 2's
-- "users update own profile" policy); only the column grant is new.
grant update (theme_color) on public.profiles to authenticated;
