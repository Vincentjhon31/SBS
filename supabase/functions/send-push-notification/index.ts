// Invoked by the `notifications_push_notify` Postgres trigger (via pg_net)
// whenever a row is inserted into public.notifications — turns it into an
// FCM push to the recipient's `user-<uid>` topic, so reminders/overdue
// alerts/approvals reach the user even if the app isn't open.
import { initializeApp, cert } from 'npm:firebase-admin@^13/app';
import { getMessaging } from 'npm:firebase-admin@^13/messaging';

const serviceAccountJson = JSON.parse(
  atob(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON_B64') ?? ''),
);
const firebaseApp = initializeApp({ credential: cert(serviceAccountJson) });

const expectedSecret = Deno.env.get('PUSH_NOTIFICATION_SECRET');

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = await req.json();
  const { recipient_id, type, title, body, borrow_request_id } = payload;

  await getMessaging(firebaseApp).send({
    topic: `user-${recipient_id}`,
    notification: { title, body },
    data: {
      type: String(type ?? ''),
      borrowRequestId: String(borrow_request_id ?? ''),
    },
    android: {
      notification: {
        channelId: 'sbs_notifications',
        sound: 'notification_sound',
      },
    },
  });

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
