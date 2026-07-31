-- Staff broadcast announcements (e.g. "Office closed for a holiday") to
-- every citizen, reusing the existing notifications table/delivery path
-- (in-app modal + push) instead of a separate channel.

alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'request_approved', 'request_rejected', 'due_soon', 'overdue', 'announcement'
  ));

create or replace function public.broadcast_announcement(p_title text, p_body text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'only staff may send announcements';
  end if;
  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then
    raise exception 'title and body are required';
  end if;

  insert into notifications (recipient_id, type, title, body)
  select id, 'announcement', p_title, p_body
  from profiles
  where user_type = 'citizen' and active;

  perform public.log_audit(
    'broadcast_announcement', 'notification', null,
    jsonb_build_object('title', p_title)
  );
end;
$$;

revoke execute on function public.broadcast_announcement(text, text) from public, anon;
grant execute on function public.broadcast_announcement(text, text) to authenticated;
