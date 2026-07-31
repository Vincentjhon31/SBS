-- Admin Users management: an accounts list staff/superadmins can act on
-- (verify/un-verify citizen ID, promote/demote user_type, grant/revoke
-- superadmin, deactivate/reactivate), plus an audit_log every one of
-- those actions writes to for accountability.

-- ============================================================
-- audit_log — write-only from the client's perspective: every entry is
-- inserted by log_audit(), a security-definer helper only the RPCs below
-- can reach (never granted to authenticated/anon directly), so the trail
-- can't be forged or edited from the app.
-- ============================================================
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  action text not null,
  target_type text not null,
  target_id uuid,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_log enable row level security;

create policy "staff read audit log"
on public.audit_log for select
using (public.is_staff());

revoke all on public.audit_log from anon, authenticated;
grant select on public.audit_log to authenticated;

create or replace function public.log_audit(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_log (actor_id, action, target_type, target_id, detail)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_detail);
end;
$$;

revoke all on function public.log_audit(text, text, uuid, jsonb) from public, anon, authenticated;

-- ============================================================
-- profiles.active — reversible account deactivation. Enforced at
-- sign-in/app-boot (the client checks this and force-signs-out with a
-- message) rather than in every RLS policy — this is an LGU admin tool,
-- not a hard security boundary.
-- ============================================================
alter table public.profiles
  add column active boolean not null default true;

-- ============================================================
-- Verify / un-verify a citizen's ID (verify_citizen already exists,
-- verify-only, used by the approvals flow — left untouched). This is the
-- two-way toggle for the Users screen.
-- ============================================================
create or replace function public.set_citizen_verified(p_citizen_id uuid, p_verified boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'only staff may change citizen verification';
  end if;
  update citizen_profiles
  set
    verified = p_verified,
    verified_by = case when p_verified then auth.uid() else null end,
    verified_at = case when p_verified then now() else null end
  where id = p_citizen_id;
  if not found then
    raise exception 'citizen profile not found';
  end if;
  perform public.log_audit(
    case when p_verified then 'citizen_verified' else 'citizen_unverified' end,
    'profile', p_citizen_id, '{}'::jsonb
  );
end;
$$;

revoke execute on function public.set_citizen_verified(uuid, boolean) from public, anon;
grant execute on function public.set_citizen_verified(uuid, boolean) to authenticated;

-- ============================================================
-- Promote/demote between citizen and staff. Superadmin-only — a user_type
-- change is more consequential than anything a regular Approver should
-- grant themselves.
-- ============================================================
create or replace function public.set_user_type(p_user_id uuid, p_user_type text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_superadmin() then
    raise exception 'only superadmins may change a user''s role';
  end if;
  if p_user_type not in ('staff', 'citizen') then
    raise exception 'invalid user_type: %', p_user_type;
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot change your own account type';
  end if;
  update profiles set user_type = p_user_type where id = p_user_id;
  if not found then
    raise exception 'profile not found';
  end if;
  perform public.log_audit('set_user_type', 'profile', p_user_id, jsonb_build_object('user_type', p_user_type));
end;
$$;

revoke execute on function public.set_user_type(uuid, text) from public, anon;
grant execute on function public.set_user_type(uuid, text) to authenticated;

-- ============================================================
-- Grant/revoke superadmin. Superadmin-only, with a guard against
-- revoking the last remaining superadmin (would lock everyone out of
-- superadmin-only actions with no way back in except direct DB access).
-- ============================================================
create or replace function public.set_superadmin(p_user_id uuid, p_is_superadmin boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_remaining int;
begin
  if not public.is_superadmin() then
    raise exception 'only superadmins may grant or revoke superadmin';
  end if;
  if not p_is_superadmin then
    select count(*) into v_remaining from profiles where is_superadmin and id != p_user_id;
    if v_remaining = 0 then
      raise exception 'cannot revoke the last remaining superadmin';
    end if;
  end if;
  update profiles set is_superadmin = p_is_superadmin where id = p_user_id;
  if not found then
    raise exception 'profile not found';
  end if;
  perform public.log_audit(
    case when p_is_superadmin then 'superadmin_granted' else 'superadmin_revoked' end,
    'profile', p_user_id, '{}'::jsonb
  );
end;
$$;

revoke execute on function public.set_superadmin(uuid, boolean) from public, anon;
grant execute on function public.set_superadmin(uuid, boolean) to authenticated;

-- ============================================================
-- Deactivate/reactivate an account. Staff may act on citizens; only
-- superadmins may act on staff/superadmin accounts (a regular Approver
-- shouldn't be able to lock out a colleague or themselves).
-- ============================================================
create or replace function public.set_account_active(p_user_id uuid, p_active boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_target_type text;
begin
  if not public.is_staff() then
    raise exception 'only staff may change account status';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot deactivate your own account';
  end if;
  select user_type into v_target_type from profiles where id = p_user_id;
  if v_target_type is null then
    raise exception 'profile not found';
  end if;
  if v_target_type = 'staff' and not public.is_superadmin() then
    raise exception 'only superadmins may change a staff account''s status';
  end if;
  update profiles set active = p_active where id = p_user_id;
  perform public.log_audit(
    case when p_active then 'account_reactivated' else 'account_deactivated' end,
    'profile', p_user_id, '{}'::jsonb
  );
end;
$$;

revoke execute on function public.set_account_active(uuid, boolean) from public, anon;
grant execute on function public.set_account_active(uuid, boolean) to authenticated;
