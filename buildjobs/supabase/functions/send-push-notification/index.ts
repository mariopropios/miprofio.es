// ── Supabase Edge Function: send-push-notification ───────────────────────────
// Notificaciones de la app: push (FCM, solo mensajes) + email (Resend).
//
// Tipos de payload:
//   { type: "message", conversation_id, sender_id, sender_name, body }
//   { type: "review", review_id, professional_id, reviewer_id, reviewer_name,
//     professional_name, rating, title, body }
//   { type: "review_reply", review_id, professional_id, reviewer_id,
//     professional_name, reply, rating, title }
//
// Secrets en Supabase → Edge Functions → Secrets:
//   FCM_SERVICE_ACCOUNT  = JSON cuenta de servicio Firebase (push)
//   RESEND_API_KEY       = API key de Resend (email)
//   MESSAGE_EMAIL_FROM   = remitente, ej. "miProfio.es <notificaciones@miprofio.es>"
//   SITE_URL             = base de deep links en emails/push
//     Ahora (sin DNS): https://profio-web.mariopropiosplaza.workers.dev
//     Producción:      https://miprofio.es  ← cambiar solo este secret cuando el dominio esté online

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type NotificationType = "message" | "review" | "review_reply";

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

const DEFAULT_SITE_URL = "https://miprofio.es";

const MESSAGE_EMAIL_COOLDOWN_MIN = 2;
const REVIEW_EMAIL_COOLDOWN_MIN = 10080; // ~1 semana; 1 email por reseña
const REVIEW_REPLY_EMAIL_COOLDOWN_MIN = 5;

function resolveSiteUrl(): string {
  const raw = Deno.env.get("SITE_URL")?.trim();
  if (raw && raw.length > 0) return raw.replace(/\/$/, "");
  return DEFAULT_SITE_URL;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return jsonResponse("ok", 200);
  }

  try {
    const payload = await req.json();
    const type = (payload.type as NotificationType | undefined) ?? "message";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (type === "review") {
      return jsonResponse(await handleReviewEmail(supabase, payload));
    }
    if (type === "review_reply") {
      return jsonResponse(await handleReviewReplyEmail(supabase, payload));
    }
    return jsonResponse(await handleMessageNotification(supabase, payload));
  } catch (err) {
    console.error("Error en send-push-notification:", err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

async function handleMessageNotification(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
) {
  const conversation_id = String(payload.conversation_id ?? "");
  const sender_id = String(payload.sender_id ?? "");
  const sender_name = String(payload.sender_name ?? "Alguien");
  const body = String(payload.body ?? "");

  if (!conversation_id || !sender_id) {
    return { error: "missing_fields" };
  }

  const { data: conv, error: convErr } = await supabase
    .from("conversations")
    .select("user_id, professional_id")
    .eq("id", conversation_id)
    .single();

  if (convErr || !conv) {
    return { error: "conversation not found" };
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

  if (!recipientUserId) return { skipped: "no_recipient" };
  if (recipientUserId === sender_id) return { skipped: "self-message" };

  const recipient = await loadRecipient(supabase, recipientUserId);
  const siteUrl = resolveSiteUrl();
  const notificationBody = formatNotificationBody(body);
  const viewingAsProfessional = sender_id === conv.user_id;
  const chatLink = buildChatDeepLink(siteUrl, {
    conversation_id,
    professional_id: professionalId,
    sender_name,
    as_prof: viewingAsProfessional,
    peer_user_id: viewingAsProfessional
      ? (conv.user_id as string)
      : undefined,
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
    asProf: viewingAsProfessional,
    peerUserId: viewingAsProfessional
      ? (conv.user_id as string)
      : undefined,
  });

  const emailResult = await sendTemplatedEmail({
    supabase,
    recipientUserId,
    recipient,
    eventKey: `message:${conversation_id}:${recipientUserId}`,
    cooldownMinutes: MESSAGE_EMAIL_COOLDOWN_MIN,
    subject: `Nuevo mensaje de ${sender_name.trim() || "Alguien"} en miProfio.es`,
    title: "Nuevo mensaje",
    introHtml:
      `<strong style="color:#FFFFFF;">${escapeHtml(sender_name.trim() || "Alguien")}</strong> te ha escrito:`,
    preview: notificationBody,
    ctaLabel: "Ver mensaje",
    ctaLink: chatLink,
    textLines: [
      `${sender_name.trim() || "Alguien"} te ha escrito en miProfio.es:`,
      "",
      notificationBody,
      "",
      `Ver mensaje: ${chatLink}`,
    ],
  });

  return {
    success: pushResult.success === true || emailResult.success === true,
    push: pushResult,
    email: emailResult,
  };
}

async function handleReviewEmail(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
) {
  const reviewId = String(payload.review_id ?? "");
  const professionalId = String(payload.professional_id ?? "");
  const reviewerName = String(payload.reviewer_name ?? "Un cliente");
  const professionalName = String(payload.professional_name ?? "tu perfil");
  const rating = Number(payload.rating ?? 0);
  const title = String(payload.title ?? "");
  const body = String(payload.body ?? "");

  if (!reviewId || !professionalId) {
    return { error: "missing_fields" };
  }

  const { data: prof } = await supabase
    .from("professionals")
    .select("owner_id, name")
    .eq("id", professionalId)
    .maybeSingle();

  const ownerId = prof?.owner_id as string | undefined;
  if (!ownerId) return { skipped: "no_owner" };

  const recipient = await loadRecipient(supabase, ownerId);
  const siteUrl = resolveSiteUrl();
  const profileLink =
    `${siteUrl}/companies/${professionalId}?from=review`;
  const stars = formatStars(rating);
  const preview = [title.trim(), body.trim()].filter(Boolean).join(" — ") ||
    "Nueva reseña";
  const profLabel = (prof?.name as string | undefined)?.trim() ||
    professionalName;

  const emailResult = await sendTemplatedEmail({
    supabase,
    recipientUserId: ownerId,
    recipient,
    eventKey: `review:${reviewId}`,
    cooldownMinutes: REVIEW_EMAIL_COOLDOWN_MIN,
    subject: `Nueva reseña (${stars}) en ${profLabel} — miProfio.es`,
    title: "Nueva reseña",
    introHtml:
      `<strong style="color:#FFFFFF;">${escapeHtml(reviewerName)}</strong> ha dejado una reseña en <strong style="color:#FFFFFF;">${escapeHtml(profLabel)}</strong>:`,
    preview: `${stars}\n${preview}`,
    ctaLabel: "Ver reseña",
    ctaLink: profileLink,
    textLines: [
      `${reviewerName} ha dejado una reseña en ${profLabel}:`,
      stars,
      preview,
      "",
      `Ver reseña: ${profileLink}`,
    ],
  });

  return { success: emailResult.success === true, email: emailResult };
}

async function handleReviewReplyEmail(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
) {
  const reviewId = String(payload.review_id ?? "");
  const professionalId = String(payload.professional_id ?? "");
  const reviewerId = String(payload.reviewer_id ?? "");
  const professionalName = String(payload.professional_name ?? "Un profesional");
  const reply = String(payload.reply ?? "");

  if (!reviewId || !professionalId || !reviewerId) {
    return { error: "missing_fields" };
  }

  const recipient = await loadRecipient(supabase, reviewerId);
  const siteUrl = resolveSiteUrl();
  const profileLink =
    `${siteUrl}/companies/${professionalId}?from=review_reply`;
  const preview = reply.trim() || "El profesional ha respondido a tu reseña.";

  const emailResult = await sendTemplatedEmail({
    supabase,
    recipientUserId: reviewerId,
    recipient,
    eventKey: `review_reply:${reviewId}`,
    cooldownMinutes: REVIEW_REPLY_EMAIL_COOLDOWN_MIN,
    subject:
      `${professionalName.trim() || "Un profesional"} respondió a tu reseña — miProfio.es`,
    title: "Respuesta a tu reseña",
    introHtml:
      `<strong style="color:#FFFFFF;">${escapeHtml(professionalName.trim() || "Un profesional")}</strong> ha respondido a tu reseña:`,
    preview,
    ctaLabel: "Ver respuesta",
    ctaLink: profileLink,
    textLines: [
      `${professionalName.trim() || "Un profesional"} ha respondido a tu reseña:`,
      "",
      preview,
      "",
      `Ver respuesta: ${profileLink}`,
    ],
  });

  return { success: emailResult.success === true, email: emailResult };
}

async function loadRecipient(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<RecipientProfile | null> {
  const { data } = await supabase
    .from("profiles")
    .select("email, fcm_token, fcm_platform, message_email_notifications")
    .eq("id", userId)
    .maybeSingle();
  return data as RecipientProfile | null;
}

async function sendTemplatedEmail(args: {
  supabase: ReturnType<typeof createClient>;
  recipientUserId: string;
  recipient: RecipientProfile | null;
  eventKey: string;
  cooldownMinutes: number;
  subject: string;
  title: string;
  introHtml: string;
  preview: string;
  ctaLabel: string;
  ctaLink: string;
  textLines: string[];
}): Promise<Record<string, unknown>> {
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) return { skipped: "resend_not_configured" };

  if (args.recipient?.message_email_notifications === false) {
    return { skipped: "email_disabled" };
  }

  const recipientEmail = args.recipient?.email?.trim();
  if (!recipientEmail) return { skipped: "no_email" };

  const claimed = await claimThrottle(
    args.supabase,
    args.eventKey,
    args.cooldownMinutes,
  );
  if (!claimed) return { skipped: "throttled" };

  const from = Deno.env.get("MESSAGE_EMAIL_FROM") ??
    "miProfio.es <notificaciones@miprofio.es>";

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [recipientEmail],
      subject: args.subject,
      html: buildEmailHtml({
        title: args.title,
        introHtml: args.introHtml,
        preview: args.preview,
        ctaLabel: args.ctaLabel,
        ctaLink: args.ctaLink,
      }),
      text: args.textLines.join("\n"),
    }),
  });

  const result = await res.json();
  if (!res.ok) {
    console.error("Resend error:", JSON.stringify(result));
    await releaseThrottle(args.supabase, args.eventKey);
    return { success: false, error: result?.message ?? "email_send_failed" };
  }

  return { success: true, id: result.id };
}

async function claimThrottle(
  supabase: ReturnType<typeof createClient>,
  eventKey: string,
  cooldownMinutes: number,
): Promise<boolean> {
  const { data, error } = await supabase.rpc(
    "try_claim_notification_throttle",
    {
      p_event_key: eventKey,
      p_cooldown_minutes: cooldownMinutes,
    },
  );

  if (error) {
    // Fallback si la migración aún no está aplicada.
    console.warn("throttle rpc failed, allowing send:", error.message);
    return true;
  }
  return data === true;
}

async function releaseThrottle(
  supabase: ReturnType<typeof createClient>,
  eventKey: string,
): Promise<void> {
  await supabase
    .from("notification_email_throttle")
    .delete()
    .eq("event_key", eventKey);
}

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
  asProf?: boolean;
  peerUserId?: string;
}): Promise<Record<string, unknown>> {
  const fcmToken = args.recipient?.fcm_token;
  if (!fcmToken) return { skipped: "no_token" };

  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountJson) return { skipped: "fcm_not_configured" };

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
          as_prof: args.asProf,
          peer_user_id: args.peerUserId,
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

function buildEmailHtml(args: {
  title: string;
  introHtml: string;
  preview: string;
  ctaLabel: string;
  ctaLink: string;
}): string {
  const safeTitle = escapeHtml(args.title);
  const safePreview = escapeHtml(args.preview).replaceAll("\n", "<br>");
  const safeLink = escapeHtml(args.ctaLink);
  const safeCta = escapeHtml(args.ctaLabel);

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
          <p style="margin:0;color:#FFFFFF;font-size:20px;font-weight:700;">${safeTitle}</p>
          <p style="margin:8px 0 0;color:#9BA3AF;font-size:15px;line-height:1.5;">
            ${args.introHtml}
          </p>
        </td></tr>
        <tr><td style="padding:16px 24px;">
          <div style="background:#12161A;border-radius:8px;padding:14px 16px;color:#E5E7EB;font-size:15px;line-height:1.5;">
            ${safePreview}
          </div>
        </td></tr>
        <tr><td style="padding:8px 24px 28px;">
          <a href="${safeLink}" style="display:inline-block;background:#00B27A;color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:8px;font-size:16px;">
            ${safeCta}
          </a>
        </td></tr>
        <tr><td style="padding:0 24px 24px;">
          <p style="margin:0;color:#6B7280;font-size:12px;line-height:1.5;">
            Si el botón no funciona, copia este enlace:<br>
            <a href="${safeLink}" style="color:#00B27A;word-break:break-all;">${safeLink}</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function formatStars(rating: number): string {
  const n = Math.max(0, Math.min(5, Math.round(rating)));
  return `${"★".repeat(n)}${"☆".repeat(5 - n)} (${n}/5)`;
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
    as_prof?: boolean;
    peer_user_id?: string;
  },
): string {
  const base = siteUrl.replace(/\/$/, "");
  const params = new URLSearchParams();
  if (data.conversation_id) params.set("conversationId", data.conversation_id);
  if (data.sender_name) params.set("name", data.sender_name);
  if (data.as_prof) params.set("asProf", "1");
  if (data.peer_user_id) params.set("peerUserId", data.peer_user_id);
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
