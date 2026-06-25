import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OTP_LENGTH = 6;
const OTP_TTL_MINUTES = 10;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 5;

type SendBody = { action: "send"; phone: string };
type VerifyBody = { action: "verify"; phone: string; code: string };
type RequestBody = SendBody | VerifyBody;

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizePhone(phone: string): string | null {
  const trimmed = phone.trim();
  if (!/^\+\d{8,15}$/.test(trimmed)) return null;
  return trimmed;
}

function generateCode(): string {
  const max = 10 ** OTP_LENGTH;
  const num = crypto.getRandomValues(new Uint32Array(1))[0] % max;
  return num.toString().padStart(OTP_LENGTH, "0");
}

async function hashCode(code: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(`${salt}:${code}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function sendSms(phone: string, code: string): Promise<boolean> {
  const sid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const token = Deno.env.get("TWILIO_AUTH_TOKEN");
  const from = Deno.env.get("TWILIO_PHONE_NUMBER");

  if (!sid || !token || !from) {
    console.log(`[phone-otp] SMS no configurado. Código para ${phone}: ${code}`);
    return false;
  }

  const body = new URLSearchParams({
    To: phone,
    From: from,
    Body: `Tu código de verificación BuildJobs es: ${code}. Válido ${OTP_TTL_MINUTES} min.`,
  });

  const auth = btoa(`${sid}:${token}`);
  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  );

  if (!res.ok) {
    const err = await res.text();
    console.error("[phone-otp] Twilio error:", err);
    throw new Error("No se pudo enviar el SMS.");
  }

  return true;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Método no permitido" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const otpSalt = Deno.env.get("OTP_SALT") ?? "buildjobs-otp-salt";
  const allowDevResponse = Deno.env.get("ALLOW_DEV_OTP_RESPONSE") === "true";

  const admin = createClient(supabaseUrl, serviceKey);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }

  if (body.action === "send") {
    const phone = normalizePhone(body.phone);
    if (!phone) {
      return json({ error: "Teléfono inválido. Usa formato E.164 (+34...)." }, 400);
    }

    const { data: recent } = await admin
      .from("phone_otp_requests")
      .select("created_at")
      .eq("phone_e164", phone)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (recent?.created_at) {
      const elapsed =
        (Date.now() - new Date(recent.created_at).getTime()) / 1000;
      if (elapsed < RESEND_COOLDOWN_SECONDS) {
        return json({
          error: "Espera antes de solicitar otro código.",
          resendAfterSeconds: Math.ceil(RESEND_COOLDOWN_SECONDS - elapsed),
        }, 429);
      }
    }

    const code = generateCode();
    const codeHash = await hashCode(code, otpSalt);
    const expiresAt = new Date(
      Date.now() + OTP_TTL_MINUTES * 60 * 1000,
    ).toISOString();

    const { data: row, error } = await admin
      .from("phone_otp_requests")
      .insert({
        phone_e164: phone,
        code_hash: codeHash,
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (error) {
      console.error("[phone-otp] insert error:", error);
      return json({ error: "No se pudo generar el código." }, 500);
    }

    let smsSent = false;
    try {
      smsSent = await sendSms(phone, code);
    } catch (e) {
      return json({ error: (e as Error).message }, 502);
    }

    const response: Record<string, unknown> = {
      requestId: row.id,
      resendAfterSeconds: RESEND_COOLDOWN_SECONDS,
      smsSent,
      message: smsSent
        ? "Código enviado por SMS."
        : "Código generado. Revisa la configuración SMS del servidor.",
    };

    if (allowDevResponse && !smsSent) {
      response.devCode = code;
    }

    return json(response);
  }

  if (body.action === "verify") {
    const phone = normalizePhone(body.phone);
    const code = body.code?.trim();

    if (!phone || !code || !/^\d{6}$/.test(code)) {
      return json({ error: "Teléfono o código inválido." }, 400);
    }

    const { data: row, error } = await admin
      .from("phone_otp_requests")
      .select("*")
      .eq("phone_e164", phone)
      .is("verified_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !row) {
      return json({ error: "Código expirado o no solicitado. Pide uno nuevo." }, 400);
    }

    if (row.attempt_count >= MAX_ATTEMPTS) {
      return json({ error: "Demasiados intentos. Solicita un código nuevo." }, 429);
    }

    const codeHash = await hashCode(code, otpSalt);
    const valid = codeHash === row.code_hash;

    await admin
      .from("phone_otp_requests")
      .update({ attempt_count: row.attempt_count + 1 })
      .eq("id", row.id);

    if (!valid) {
      const remaining = MAX_ATTEMPTS - row.attempt_count - 1;
      return json({
        error: remaining > 0
          ? `Código incorrecto. Te quedan $remaining intentos.`
          : "Código incorrecto. Solicita uno nuevo.",
      }, 400);
    }

    await admin
      .from("phone_otp_requests")
      .update({ verified_at: new Date().toISOString() })
      .eq("id", row.id);

    return json({
      verified: true,
      verificationId: row.id,
      phone,
    });
  }

  return json({ error: "Acción no válida" }, 400);
});
