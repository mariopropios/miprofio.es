// ── Supabase Edge Function: cleanup-unconfirmed-users ────────────────────────
// Borra usuarios NO verificados (email_confirmed_at null) más antiguos que X horas.
//
// Requiere SUPABASE_SERVICE_ROLE_KEY (ya existe para otras funciones).
//
// Uso (manual):
//  supabase functions invoke cleanup-unconfirmed-users --no-verify-jwt --data '{"older_than_hours":48,"dry_run":true}'
//
// Uso (automático):
//  Configura un "Scheduled Trigger" en Supabase para llamarla (ej. cada hora).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  older_than_hours?: number;
  dry_run?: boolean;
  max_delete?: number;
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Configuración del servidor incompleta." }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Body = {};
  try {
    body = (await req.json()) as Body;
  } catch (_) {}

  const olderThanHours = Math.max(1, Number(body.older_than_hours ?? 48));
  const dryRun = Boolean(body.dry_run ?? false);
  const maxDelete = Math.max(1, Number(body.max_delete ?? 200));

  const cutoffMs = Date.now() - olderThanHours * 60 * 60 * 1000;
  const cutoffIso = new Date(cutoffMs).toISOString();

  let deleted = 0;
  let scanned = 0;
  const errors: Array<{ user_id: string; error: string }> = [];
  const candidates: string[] = [];

  // listUsers está paginado; iteramos hasta cubrir el límite de borrado.
  let page = 1;
  const perPage = 1000;

  while (deleted + candidates.length < maxDelete) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error) {
      return json({ error: error.message }, 500);
    }

    const users = data.users ?? [];
    if (users.length === 0) break;

    for (const u of users) {
      scanned++;
      if (u.email_confirmed_at) continue;
      if (!u.created_at) continue;
      if (u.created_at > cutoffIso) continue;
      if (!u.id) continue;
      candidates.push(u.id);
      if (deleted + candidates.length >= maxDelete) break;
    }

    // Heurística: si la página vino incompleta, ya no hay más.
    if (users.length < perPage) break;
    page++;
    if (page > 100) break; // safety guard
  }

  if (dryRun) {
    return json({
      ok: true,
      dry_run: true,
      older_than_hours: olderThanHours,
      cutoff: cutoffIso,
      scanned,
      would_delete: candidates.length,
      sample_user_ids: candidates.slice(0, 25),
    });
  }

  for (const userId of candidates) {
    try {
      // Limpiar profile primero (por si hay FKs/refs).
      await admin.from("profiles").delete().eq("id", userId);

      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) {
        errors.push({ user_id: userId, error: error.message });
        continue;
      }
      deleted++;
    } catch (e) {
      errors.push({ user_id: userId, error: String(e) });
    }
  }

  return json({
    ok: true,
    older_than_hours: olderThanHours,
    cutoff: cutoffIso,
    scanned,
    candidates: candidates.length,
    deleted,
    errors,
  });
});
