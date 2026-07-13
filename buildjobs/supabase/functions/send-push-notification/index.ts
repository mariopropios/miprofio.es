// ── Supabase Edge Function: send-push-notification ───────────────────────────
// Envía push via Firebase Cloud Messaging HTTP v1 (API moderna).
//
// Secret en Supabase → Edge Functions → Secrets:
//   FCM_SERVICE_ACCOUNT = JSON completo de la cuenta de servicio de Firebase
//   SITE_URL (opcional) = https://miprofio.es

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const payload: PushPayload = await req.json();
    const { conversation_id, sender_id, sender_name, body } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: conv, error: convErr } = await supabase
      .from("conversations")
      .select("user_id, professional_id")
      .eq("id", conversation_id)
      .single();

    if (convErr || !conv) {
      return jsonResponse({ error: "conversation not found" }, 404);
    }

    const professionalId = conv.professional_id as string;
    let recipientUserId: string | null = null;

    if (sender_id === conv.user_id) {
      const { data: prof } = await supabase
        .from("professionals")
        .select("owner_id")
        .eq("id", professionalId)
        .maybeSingle();

      recipientUserId = (prof?.owner_id as string | undefined) ?? null;
    } else {
      recipientUserId = conv.user_id as string;
    }

    if (!recipientUserId) {
      // No hay dueño asignado a ese profesional: no existe un destinatario válido.
      return jsonResponse({ skipped: "no_recipient" });
    }

    if (recipientUserId === sender_id) {
      return jsonResponse({ skipped: "self-message" });
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("fcm_token, fcm_platform")
      .eq("id", recipientUserId)
      .maybeSingle();

    const fcmToken = profile?.fcm_token;
    if (!fcmToken) {
      return jsonResponse({ skipped: "no_token" });
    }

    const fcmPlatform = (profile?.fcm_platform as string | undefined) ?? "web";

    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return jsonResponse({ error: "FCM_SERVICE_ACCOUNT missing" }, 500);
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getFcmAccessToken(serviceAccount);

    const notificationBody = formatNotificationBody(body);
    const siteUrl = Deno.env.get("SITE_URL") ?? "https://miprofio.es";

    const messagePayload: Record<string, unknown> = {
      token: fcmToken,
      data: {
        conversation_id,
        professional_id: professionalId,
        sender_id,
        sender_name,
        body: notificationBody,
        timestamp: String(Date.now()),
      },
      webpush: {
        headers: { Urgency: "high" },
      },
    };

    const notificationTitle = sender_name || "Nuevo mensaje";

    // iOS PWA no muestra pushes solo-data; necesita notification + APNs.
    if (fcmPlatform === "web_ios") {
      messagePayload.notification = {
        title: notificationTitle,
        body: notificationBody,
      };
      messagePayload.apns = {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: notificationTitle,
              body: notificationBody,
            },
            sound: "default",
          },
        },
      };
      messagePayload.webpush = {
        headers: { Urgency: "high" },
        notification: {
          title: notificationTitle,
          body: notificationBody,
          icon: `${siteUrl}/favicon.png`,
        },
        fcm_options: {
          link: buildChatDeepLink(siteUrl, {
            conversation_id,
            professional_id: professionalId,
            sender_name,
          }),
        },
      };
    }

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message: messagePayload }),
      },
    );

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error("FCM error:", JSON.stringify(fcmResult));

      const errorCode =
        fcmResult?.error?.details?.[0]?.errorCode ?? fcmResult?.error?.status;

      if (
        errorCode === "UNREGISTERED" ||
        fcmResult?.error?.message?.includes(
          "not a valid FCM registration token",
        )
      ) {
        await supabase
          .from("profiles")
          .update({ fcm_token: null, fcm_platform: null })
          .eq("id", recipientUserId);
      }

      return jsonResponse(
        { error: fcmResult?.error?.message ?? "FCM error" },
        400,
      );
    }

    return jsonResponse({ success: true, fcm: fcmResult });
  } catch (err) {
    console.error("Error en send-push-notification:", err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

function formatNotificationBody(body: string): string {
  if (body.startsWith("[image]")) return "Imagen";
  if (body.startsWith("[audio]")) return "Audio";
  return body.length > 100 ? `${body.substring(0, 97)}...` : body;
}

function buildChatDeepLink(
  siteUrl: string,
  data: {
    conversation_id: string;
    professional_id: string;
    sender_name: string;
  },
): string {
  const base = siteUrl.replace(/\/$/, "");
  const params = new URLSearchParams();
  if (data.conversation_id) params.set("conversationId", data.conversation_id);
  if (data.sender_name) params.set("name", data.sender_name);
  const qs = params.toString();
  return `${base}/messages/${data.professional_id}${qs ? `?${qs}` : ""}`;
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const pemKey = sa.private_key.replace(/\\n/g, "\n");
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(pemKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    cryptoKey,
  );

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
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
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
