// ── Supabase Edge Function: send-push-notification ───────────────────────────
// Envía push via Firebase Cloud Messaging HTTP v1 (API moderna).
//
// Secret en Supabase → Edge Functions → Secrets:
//   FCM_SERVICE_ACCOUNT = JSON completo de la cuenta de servicio de Firebase
//     (Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface PushPayload {
  conversation_id: string;
  sender_id: string;
  sender_name: string;
  body: string;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const payload: PushPayload = await req.json();
    const { conversation_id, sender_id, sender_name, body } = payload;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: conv, error: convErr } = await supabase
      .from('conversations')
      .select('user_id, professional_id')
      .eq('id', conversation_id)
      .single();

    if (convErr || !conv) {
      return jsonResponse({ error: 'conversation not found' }, 404);
    }

    let recipientUserId: string;

    if (sender_id === conv.user_id) {
      const { data: prof } = await supabase
        .from('professionals')
        .select('owner_id')
        .eq('id', conv.professional_id)
        .maybeSingle();

      recipientUserId = prof?.owner_id ?? conv.professional_id;
    } else {
      recipientUserId = conv.user_id;
    }

    if (recipientUserId === sender_id) {
      return jsonResponse({ skipped: 'self-message' });
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', recipientUserId)
      .maybeSingle();

    const fcmToken = profile?.fcm_token;
    if (!fcmToken) {
      return jsonResponse({ skipped: 'no_token' });
    }

    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT');
    if (!serviceAccountJson) {
      return jsonResponse({ error: 'FCM_SERVICE_ACCOUNT missing' }, 500);
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getFcmAccessToken(serviceAccount);

    const truncatedBody =
      body.length > 100 ? `${body.substring(0, 97)}...` : body;

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: sender_name,
              body: truncatedBody,
            },
            data: {
              conversation_id,
              sender_id,
            },
            webpush: {
              notification: {
                icon: '/favicon.png',
              },
            },
          },
        }),
      },
    );

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error('FCM error:', JSON.stringify(fcmResult));

      const errorCode = fcmResult?.error?.details?.[0]?.errorCode
        ?? fcmResult?.error?.status;

      if (
        errorCode === 'UNREGISTERED' ||
        fcmResult?.error?.message?.includes('not a valid FCM registration token')
      ) {
        await supabase
          .from('profiles')
          .update({ fcm_token: null })
          .eq('id', recipientUserId);
      }

      return jsonResponse({ error: fcmResult?.error?.message ?? 'FCM error' }, 400);
    }

    return jsonResponse({ success: true, fcm: fcmResult });
  } catch (err) {
    console.error('Error en send-push-notification:', err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const pemKey = sa.private_key.replace(/\\n/g, '\n');
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(pemKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    },
    cryptoKey,
  );

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenRes.ok) {
    throw new Error(`OAuth error: ${JSON.stringify(tokenData)}`);
  }

  return tokenData.access_token as string;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
