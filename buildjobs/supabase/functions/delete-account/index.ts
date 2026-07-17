// Elimina la cuenta del usuario autenticado.
//
// Flujo:
// 1) Soft-delete / archivo de la ficha profesional (RPC con JWT del usuario).
// 2) Borra el usuario en Auth (service_role) → cascade de profiles, etc.
//
// Secrets (automáticos en Edge Functions):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Método no permitido" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Configuración del servidor incompleta." }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "No autenticado." }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json({ error: "Sesión no válida. Vuelve a iniciar sesión." }, 401);
    }

    // 1) Ocultar ficha pública mientras el JWT sigue válido.
    const { error: softDeleteError } = await userClient.rpc(
      "soft_delete_my_professional",
      { p_reason: "account_deleted" },
    );

    if (softDeleteError) {
      console.error("[delete-account] soft_delete:", softDeleteError);
      // Seguir: borrar auth igualmente; el trigger de owner_id null también archiva.
    }

    // 2) Borrar usuario Auth (cascade profiles; professionals.owner_id → null).
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);

    if (deleteError) {
      console.error("[delete-account] deleteUser:", deleteError);
      return json(
        {
          error:
            "No se pudo eliminar la cuenta. Inténtalo de nuevo o contacta con soporte.",
        },
        500,
      );
    }

    return json({ ok: true });
  } catch (e) {
    console.error("[delete-account]", e);
    return json({ error: "Error inesperado al eliminar la cuenta." }, 500);
  }
});
