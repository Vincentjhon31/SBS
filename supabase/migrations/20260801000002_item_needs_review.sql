-- Citizens can already self-add items directly (items_registry.sql's
-- "self-growing registry" insert policy) -- this flags citizen-added items
-- so staff can spot ones that need a category/department/proper photo,
-- without blocking the citizen's request in the meantime.

alter table public.items
  add column needs_review boolean not null default false;

create or replace function public.set_item_review_flag()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  new.needs_review := not public.is_staff();
  return new;
end;
$$;

create trigger items_set_review_flag
before insert on public.items
for each row execute function public.set_item_review_flag();

-- The update RLS policy on items is staff-only in practice
-- (can_manage_item_dept requires is_staff()), so any successful update
-- resolves the flag -- editing category/department/photo IS the review,
-- no separate "mark reviewed" action needed.
create or replace function public.clear_item_review_flag()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  new.needs_review := false;
  return new;
end;
$$;

create trigger items_clear_review_flag
before update on public.items
for each row execute function public.clear_item_review_flag();
