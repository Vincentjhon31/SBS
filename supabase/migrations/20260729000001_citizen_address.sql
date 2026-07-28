-- Profile Information (Settings redesign) needs an address field that
-- never existed on citizen_profiles — nullable so existing rows aren't
-- affected, and self-editable like the other citizen-owned fields.
alter table public.citizen_profiles
  add column address text;

grant update (address) on public.citizen_profiles to authenticated;
