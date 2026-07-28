-- Delivers every notification row as an FCM push, not just the in-app
-- realtime stream — see the note on public.notifications ("the same rows
-- become the source for FCM push once Firebase credentials exist").
--
-- The Edge Function URL + a shared bearer secret are stored in Vault so
-- this trigger function never contains a raw secret; the same secret value
-- must also be set as the send-push-notification function's own
-- PUSH_NOTIFICATION_SECRET (see supabase/functions/send-push-notification).
create extension if not exists pg_net;
create extension if not exists pgcrypto;

select vault.create_secret(
  'https://ppbrkgnikipfhppvdwfp.supabase.co/functions/v1/send-push-notification',
  'push_notification_url'
);
select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'push_notification_secret'
);

create or replace function public.notify_push_on_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  function_url text;
  shared_secret text;
begin
  select decrypted_secret into function_url
  from vault.decrypted_secrets where name = 'push_notification_url';
  select decrypted_secret into shared_secret
  from vault.decrypted_secrets where name = 'push_notification_secret';

  -- Fire-and-forget: pg_net queues the request asynchronously, so a slow or
  -- failing push never blocks or fails the notification insert itself.
  perform net.http_post(
    url => function_url,
    headers => jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || shared_secret
    ),
    body => jsonb_build_object(
      'recipient_id', new.recipient_id,
      'type', new.type,
      'title', new.title,
      'body', new.body,
      'borrow_request_id', new.borrow_request_id
    )
  );
  return new;
end;
$$;

revoke execute on function public.notify_push_on_insert() from public, anon, authenticated;

create trigger notifications_push_notify
after insert on public.notifications
for each row execute function public.notify_push_on_insert();
