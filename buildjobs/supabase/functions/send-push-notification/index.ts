// ── Supabase Edge Function: send-push-notification ───────────────────────────
// Envía push (FCM) y/o email (Resend) al recibir un mensaje nuevo.
//
// Secrets en Supabase → Edge Functions → Secrets:
//   FCM_SERVICE_ACCOUNT  = JSON cuenta de servicio Firebase (push)
//   RESEND_API_KEY       = API key de Resend (email)
//   MESSAGE_EMAIL_FROM   = remitente, ej. "miProfio.es <notificaciones@miprofio.es>"
//   SITE_URL (opcional)  = https://miprofio.es

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

interface RecipientProfile {
  email: string | null;
  fcm_token: string | null;
  fcm_platform: string | null;
  message_email_notifications: boolean | null;
}

const EMAIL_THROTTLE_MINUTES = 10;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return jsonResponse("ok", 200);
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
      return jsonResponse({ skipped: "no_recipient" });
    }

    if (recipientUserId === sender_id) {
      return jsonResponse({ skipped: "self-message" });
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("email, fcm_token, fcm_platform, message_email_notifications")
      .eq("id", recipientUserId)
      .maybeSingle();

    const recipient = profile as RecipientProfile | null;
    const siteUrl = Deno.env.get("SITE_URL") ?? "https://miprofio.es";
    const notificationBody = formatNotificationBody(body);
    const chatLink = buildChatDeepLink(siteUrl, {
      conversation_id,
      professional_id: professionalId,
      sender_name,
    });

    const pushResult = await sendPushIfPossible({
      supabase,
      recipientUserId,
      recipient,
      conversation_id,
      professionalId,
      sender_id,
      sender_name,
      notificationBody,
      siteUrl,
    });

    const emailResult = await sendEmailIfPossible({
      supabase,
      recipientUserId,
      recipient,
      conversation_id,
      sender_name,
      notificationBody,
      chatLink,
    });

    const anySuccess =
      pushResult.success === true || emailResult.success === true;

    return jsonResponse({
      success: anySuccess,
      push: pushResult,
      email: emailResult,
    });
  } catch (err) {
    console.error("Error en send-push-notification:", err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

async function sendPushIfPossible(args: {
  supabase: ReturnType<typeof createClient>;
  recipientUserId: string;
  recipient: RecipientProfile | null;
  conversation_id: string;
  professionalId: string;
  sender_id: string;
  sender_name: string;
  notificationBody: string;
  siteUrl: string;
}): Promise<Record<string, unknown>> {
  const fcmToken = args.recipient?.fcm_token;
  if (!fcmToken) {
    return { skipped: "no_token" };
  }

  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountJson) {
    return { skipped: "fcm_not_configured" };
  }

  const fcmPlatform = args.recipient?.fcm_platform ?? "web";
  const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
  const accessToken = await getFcmAccessToken(serviceAccount);
  const notificationTitle = args.sender_name || "Nuevo mensaje";

  const messagePayload: Record<string, unknown> = {
    token: fcmToken,
    data: {
      conversation_id: args.conversation_id,
      professional_id: args.professionalId,
      sender_id: args.sender_id,
      sender_name: args.sender_name,
      body: args.notificationBody,
      timestamp: String(Date.now()),
    },
    webpush: {
      headers: { Urgency: "high" },
    },
  };

  if (fcmPlatform === "web_ios") {
    messagePayload.notification = {
      title: notificationTitle,
      body: args.notificationBody,
    };
    messagePayload.apns = {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: {
            title: notificationTitle,
            body: args.notificationBody,
          },
          sound: "default",
        },
      },
    };
    messagePayload.webpush = {
      headers: { Urgency: "high" },
      notification: {
        title: notificationTitle,
        body: args.notificationBody,
        icon: `${args.siteUrl}/favicon.png`,
      },
      fcm_options: {
        link: buildChatDeepLink(args.siteUrl, {
          conversation_id: args.conversation_id,
          professional_id: args.professionalId,
          sender_name: args.sender_name,
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
      await args.supabase
        .from("profiles")
        .update({ fcm_token: null, fcm_platform: null })
        .eq("id", args.recipientUserId);
    }

    return { success: false, error: fcmResult?.error?.message ?? "FCM error" };
  }

  return { success: true, fcm: fcmResult };
}

async function sendEmailIfPossible(args: {
  supabase: ReturnType<typeof createClient>;
  recipientUserId: string;
  recipient: RecipientProfile | null;
  conversation_id: string;
  sender_name: string;
  notificationBody: string;
  chatLink: string;
}): Promise<Record<string, unknown>> {
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    return { skipped: "resend_not_configured" };
  }

  if (args.recipient?.message_email_notifications === false) {
    return { skipped: "email_disabled" };
  }

  const recipientEmail = args.recipient?.email?.trim();
  if (!recipientEmail) {
    return { skipped: "no_email" };
  }

  const throttled = await isEmailThrottled(
    args.supabase,
    args.conversation_id,
    args.recipientUserId,
  );
  if (throttled) {
    return { skipped: "throttled" };
  }

  const from = Deno.env.get("MESSAGE_EMAIL_FROM") ??
    "miProfio.es <notificaciones@miprofio.es>";
  const senderLabel = args.sender_name?.trim() || "Alguien";
  const subject = `Nuevo mensaje de ${senderLabel} en miProfio.es`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [recipientEmail],
      subject,
      html: buildEmailHtml({
        senderName: senderLabel,
        preview: args.notificationBody,
        chatLink: args.chatLink,
      }),
      text: [
        `${senderLabel} te ha escrito en miProfio.es:`,
        "",
        args.notificationBody,
        "",
        `Ver mensaje: ${args.chatLink}`,
      ].join("\n"),
    }),
  });

  const result = await res.json();
  if (!res.ok) {
    console.error("Resend error:", JSON.stringify(result));
    return {
      success: false,
      error: result?.message ?? "email_send_failed",
    };
  }

  await args.supabase.from("message_email_throttle").upsert({
    conversation_id: args.conversation_id,
    recipient_id: args.recipientUserId,
    last_sent_at: new Date().toISOString(),
  });

  return { success: true, id: result.id };
}

async function isEmailThrottled(
  supabase: ReturnType<typeof createClient>,
  conversationId: string,
  recipientId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("message_email_throttle")
    .select("last_sent_at")
    .eq("conversation_id", conversationId)
    .eq("recipient_id", recipientId)
    .maybeSingle();

  if (!data?.last_sent_at) return false;

  const last = new Date(data.last_sent_at as string).getTime();
  const elapsedMs = Date.now() - last;
  return elapsedMs < EMAIL_THROTTLE_MINUTES * 60 * 1000;
}

function buildEmailHtml(args: {
  senderName: string;
  preview: string;
  chatLink: string;
}): string {
  const safeName = escapeHtml(args.senderName);
  const safePreview = escapeHtml(args.preview);
  const safeLink = escapeHtml(args.chatLink);

  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#12161A;font-family:system-ui,-apple-system,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#12161A;padding:24px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:480px;background:#1A2329;border-radius:12px;overflow:hidden;">
        <tr><td style="padding:24px 24px 8px;">
          <p style="margin:0;color:#00B27A;font-weight:700;font-size:18px;">miProfio.es</p>
        </td></tr>
        <tr><td style="padding:8px 24px 0;">
          <p style="margin:0;color:#FFFFFF;font-size:20px;font-weight:700;">Nuevo mensaje</p>
          <p style="margin:8px 0 0;color:#9BA3AF;font-size:15px;line-height:1.5;">
            <strong style="color:#FFFFFF;">${safeName}</strong> te ha escrito:
          </p>
        </td></tr>
        <tr><td style="padding:16px 24px;">
          <div style="background:#12161A;border-radius:8px;padding:14px 16px;color:#E5E7EB;font-size:15px;line-height:1.5;">
            ${safePreview}
          </div>
        </td></tr>
        <tr><td style="padding:8px 24px 28px;">
          <a href="${safeLink}" style="display:inline-block;background:#00B27A;color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:8px;font-size:16px;">
            Ver mensaje
          </a>
        </td></tr>
        <tr><td style="padding:0 24px 24px;">
          <p style="margin:0;color:#6B7280;font-size:12px;line-height:1.5;">
            Si el botón no funciona, copia este enlace en Safari:<br>
            <a href="${safeLink}" style="color:#00B27A;word-break:break-all;">${safeLink}</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

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
  return new Response(
    typeof data === "string" ? data : JSON.stringify(data),
    {
      status,
      headers: {
        "Content-Type": typeof data === "string"
          ? "text/plain"
          : "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    },
  );
}
