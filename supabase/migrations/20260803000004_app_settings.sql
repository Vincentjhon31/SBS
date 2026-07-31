-- Editable system settings: policy text that was previously hardcoded in
-- AppConstants becomes superadmin-editable without a code change/release.
-- Seeded with today's hardcoded values so behavior is unchanged until
-- someone actually edits a setting.

create table public.app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id)
);

alter table public.app_settings enable row level security;

-- Readable by everyone signed in (citizens need the policy text too);
-- writes only via the RPC below.
create policy "authenticated read app settings"
on public.app_settings for select
using (true);

revoke all on public.app_settings from anon, authenticated;
grant select on public.app_settings to authenticated;

insert into public.app_settings (key, value) values
  ('liability_terms_version', 'v1'),
  ('liability_terms',
    'I acknowledge receiving this item in the condition shown in the '
    'photos taken at handoff. I agree to return it in the same condition '
    'on or before the stated due date, and I accept responsibility for '
    'loss or damage while it is in my care.'),
  ('data_policy_statement',
    'Your photo and ID information are used solely to verify borrowing '
    'transactions with the LGU. You can request an export or deletion of '
    'your personal data at any time from Settings.')
on conflict (key) do nothing;

create or replace function public.set_app_setting(p_key text, p_value text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_superadmin() then
    raise exception 'only superadmins may edit system settings';
  end if;
  insert into app_settings (key, value, updated_at, updated_by)
  values (p_key, p_value, now(), auth.uid())
  on conflict (key) do update
    set value = excluded.value, updated_at = now(), updated_by = auth.uid();
  perform public.log_audit('set_app_setting', 'app_settings', null, jsonb_build_object('key', p_key));
end;
$$;

revoke execute on function public.set_app_setting(text, text) from public, anon;
grant execute on function public.set_app_setting(text, text) to authenticated;
