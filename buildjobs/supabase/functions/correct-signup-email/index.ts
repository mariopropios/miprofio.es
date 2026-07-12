import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type RequestBody = {
  userId?: string;
  oldEmail?: string;
  newEmail?: string;
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidEmail(email: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Método no permitido" }, 405);
  }

  try {
    const body = (await req.json()) as RequestBody;
    const userId = body.userId?.trim();
    const oldEmail = body.oldEmail?.trim().toLowerCase();
    const newEmail = body.newEmail?.trim().toLowerCase();

    if (!userId || !oldEmail || !newEmail) {
      return json({ error: "Faltan datos para corregir el email." }, 400);
    }

    if (!isValidEmail(newEmail)) {
      return json({ error: "El nuevo email no tiene un formato válido." }, 400);
    }

    if (oldEmail === newEmail) {
      return json({ ok: true, unchanged: true });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Configuración del servidor incompleta." }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } =
      await admin.auth.admin.getUserById(userId);

    if (userError || !userData.user) {
      return json({ error: "No se encontró la cuenta pendiente." }, 404);
    }

    const user = userData.user;
    const currentEmail = user.email?.trim().toLowerCase();

    if (currentEmail !== oldEmail) {
      return json(
        { error: "El email actual no coincide con el que estás corrigiendo." },
        409,
      );
    }

    if (user.email_confirmed_at) {
      return json(
        { error: "Esta cuenta ya está verificada. Inicia sesión." },
        409,
      );
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      userId,
      {
        email: newEmail,
        email_confirm: false,
      },
    );

    if (updateError) {
      const message = updateError.message.toLowerCase();
      if (
        message.includes("already") ||
        message.includes("exists") ||
        message.includes("registered")
      ) {
        return json(
          {
            error:
              "Ese email ya está registrado. Prueba con otro o inicia sesión.",
          },
          409,
        );
      }
      if (message.includes("invalid") || message.includes("validate")) {
        return json(
          {
            error:
              "Ese email no parece válido. Revisa que esté bien escrito.",
          },
          400,
        );
      }
      console.error("[correct-signup-email]", updateError);
      return json({ error: "No se pudo actualizar el email." }, 500);
    }

    const { error: profileError } = await admin
      .from("profiles")
      .update({ email: newEmail })
      .eq("id", userId);

    if (profileError) {
      console.error("[correct-signup-email] profile", profileError);
    }

    return json({ ok: true });
  } catch (error) {
    console.error("[correct-signup-email]", error);
    return json({ error: "Error inesperado al corregir el email." }, 500);
  }
});
