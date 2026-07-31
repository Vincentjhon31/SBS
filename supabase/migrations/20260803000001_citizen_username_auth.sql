-- Citizens register/log in with a username instead of an email (staff keep
-- using email, unchanged). No auth.users lookup is needed: the synthetic
-- sign-up email is a pure, deterministic function of the username
-- (lower(username) || '@citizens.sbs.internal'), computed identically on
-- the client at sign-up and by resolve_login_identifier() at sign-in, so
-- resolution never needs elevated access to the auth schema.

alter table public.profiles
  add column username text
    check (username ~ '^[A-Za-z][A-Za-z0-9_]{2,19}$');

-- Case-insensitive uniqueness; a plain `unique` constraint would still
-- allow "Alice" and "alice" as distinct rows. NULLs (legacy accounts with
-- no username) are unaffected — a unique index never conflicts on NULL.
create unique index profiles_username_lower_idx
  on public.profiles (lower(username));

-- ============================================================
-- Signup trigger: also capture username from signUp() metadata.
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, username, user_type)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), new.email, 'Unnamed'),
    nullif(new.raw_user_meta_data ->> 'username', ''),
    case
      when new.raw_user_meta_data ->> 'user_type' = 'staff' then 'staff'
      else 'citizen'
    end
  );
  return new;
end;
$$;

-- ============================================================
-- Pre-auth RPCs (must be callable by anon, before there is a session).
-- ============================================================

-- Live availability check for the registration form.
create or replace function public.username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles where lower(username) = lower(p_username)
  );
$$;

revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- Login-time lookup: username -> the synthetic email to sign in with.
-- Returns null (not an error) for an unknown username, so the client can
-- show a generic "invalid username or password" without leaking which
-- half was wrong.
create or replace function public.resolve_login_identifier(p_username text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.profiles where lower(username) = lower(p_username);
  if v_id is null then
    return null;
  end if;
  return lower(p_username) || '@citizens.sbs.internal';
end;
$$;

revoke all on function public.resolve_login_identifier(text) from public;
grant execute on function public.resolve_login_identifier(text) to anon, authenticated;
