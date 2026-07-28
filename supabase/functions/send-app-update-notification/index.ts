// Invoked directly by .github/workflows/release.yml right after a GitHub
// Release is published — pushes to the `app-updates` topic so already
// installed users get proactively notified of new releases, not just
// users who happen to open the About page.
import { initializeApp, cert } from 'npm:firebase-admin@^13/app';
import { getMessaging } from 'npm:firebase-admin@^13/messaging';

const serviceAccountJson = JSON.parse(
  atob(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON_B64') ?? ''),
);
const firebaseApp = initializeApp({ credential: cert(serviceAccountJson) });

const expectedSecret = Deno.env.get('RELEASE_NOTIFY_SECRET');

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const { version, releaseUrl } = await req.json();

  await getMessaging(firebaseApp).send({
    topic: 'app-updates',
    notification: {
      title: 'Update available',
      body: `SBS version ${version} is ready to install.`,
    },
    data: { type: 'app_update', version: String(version ?? ''), releaseUrl: String(releaseUrl ?? '') },
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
