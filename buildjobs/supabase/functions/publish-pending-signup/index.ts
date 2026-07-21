// ── publish-pending-signup ────────────────────────────────────────────────────
// Tras confirmar email (JWT activo), publica la ficha profesional/cliente
// leyendo signup_drafts o user_metadata.pending_* con service role.
// Así funciona aunque el registro fuese en Chrome y la confirmación en Safari.

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

function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v)).filter((v) => v.length > 0);
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !serviceRoleKey || !anonKey) {
      return json({ error: "Configuración incompleta" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "No autenticado" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return json({ error: "Sesión inválida" }, 401);
    }

    const user = userData.user;
    const userId = user.id;
    const accountEmail = (user.email ?? "").trim();

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ¿Ya tiene ficha?
    const { data: existing } = await admin
      .from("professionals")
      .select("id")
      .or(`id.eq.${userId},owner_id.eq.${userId}`)
      .is("deleted_at", null)
      .limit(1)
      .maybeSingle();

    if (existing?.id) {
      return json({ ok: true, alreadyPublished: true, professionalId: existing.id });
    }

    // Draft: tabla → metadata
    let kind: string | null = null;
    let payload: Record<string, unknown> = {};

    const { data: draftRow } = await admin
      .from("signup_drafts")
      .select("kind, payload")
      .eq("user_id", userId)
      .maybeSingle();

    if (draftRow?.kind && draftRow.payload && typeof draftRow.payload === "object") {
      kind = String(draftRow.kind);
      payload = draftRow.payload as Record<string, unknown>;
    } else {
      const meta = user.user_metadata ?? {};
      if (meta.pending_professional && typeof meta.pending_professional === "object") {
        kind = "professional";
        payload = meta.pending_professional as Record<string, unknown>;
      } else if (meta.pending_client && typeof meta.pending_client === "object") {
        kind = "client";
        payload = meta.pending_client as Record<string, unknown>;
      } else if (meta.role === "professional") {
        // Metadata mínima: al menos crear ficha con nombre
        kind = "professional";
        payload = {
          businessName: meta.full_name ?? accountEmail.split("@")[0] ?? "Profesional",
          city: "",
          address: "",
          latitude: 0,
          longitude: 0,
          phoneE164: "",
          bio: "",
          professions: [],
          categories: [],
          serviceRadiusKm: 25,
          email: accountEmail,
        };
      }
    }

    if (!kind) {
      return json({ ok: false, skipped: "no_draft" }, 200);
    }

    if (kind === "client") {
      const fullName = String(payload.fullName ?? metaFullName(user) ?? "");
      const avatarUrl = String(
        payload.profilePhotoUrl ?? payload.avatarUrl ?? "",
      );
      const profileUpdate: Record<string, unknown> = {};
      if (fullName) profileUpdate.full_name = fullName;
      if (avatarUrl) profileUpdate.avatar_url = avatarUrl;
      if (Object.keys(profileUpdate).length > 0) {
        await admin.from("profiles").update(profileUpdate).eq("id", userId);
      }
      await admin.from("signup_drafts").delete().eq("user_id", userId);
      await clearPendingMeta(admin, user);
      return json({ ok: true, kind: "client" });
    }

    // professional
    const fullName = String(
      payload.businessName ?? payload.fullName ?? metaFullName(user) ?? "Profesional",
    );
    const city = String(payload.city ?? "");
    const address = String(payload.address ?? city);
    const latitude = Number(payload.latitude ?? 0);
    const longitude = Number(payload.longitude ?? 0);
    const phone = String(payload.phoneE164 ?? "");
    const bio = String(payload.bio ?? "");
    const professions = asStringList(payload.professions);
    const categories = asStringList(payload.categories);
    const serviceRadiusKm = Number(payload.serviceRadiusKm ?? 25);
    const profilePhotoUrl = payload.profilePhotoUrl
      ? String(payload.profilePhotoUrl)
      : null;
    const galleryPhotoUrls = asStringList(payload.galleryPhotoUrls);
    const email = String(payload.email ?? accountEmail);

    await admin.from("profiles").update({
      full_name: fullName,
      role: "professional",
      city: city || null,
      email,
      ...(profilePhotoUrl ? { avatar_url: profilePhotoUrl } : {}),
    }).eq("id", userId);

    const professionLabel = professions.join(", ");
    const upsertPayload: Record<string, unknown> = {
      id: userId,
      owner_id: userId,
      name: fullName,
      profession: professionLabel || "Profesional",
      description: bio,
      city,
      address: address || city,
      latitude,
      longitude,
      type: "individual",
      service_radius_km: serviceRadiusKm,
      email,
    };
    if (categories.length > 0) upsertPayload.service_categories = categories;
    if (phone) upsertPayload.phone = phone;
    if (profilePhotoUrl) upsertPayload.profile_photo = profilePhotoUrl;
    if (galleryPhotoUrls.length > 0) {
      upsertPayload.gallery_photos = galleryPhotoUrls;
    }

    const { error: upsertErr } = await admin
      .from("professionals")
      .upsert(upsertPayload, { onConflict: "id" });

    if (upsertErr) {
      // Reintento sin columnas nuevas
      console.error("professionals upsert:", upsertErr);
      delete upsertPayload.gallery_photos;
      delete upsertPayload.service_categories;
      const { error: upsertErr2 } = await admin
        .from("professionals")
        .upsert(upsertPayload, { onConflict: "id" });
      if (upsertErr2) {
        return json({ error: upsertErr2.message }, 500);
      }
    }

    await admin.from("signup_drafts").delete().eq("user_id", userId);
    await clearPendingMeta(admin, user);

    return json({
      ok: true,
      kind: "professional",
      professionalId: userId,
      name: fullName,
    });
  } catch (err) {
    console.error("publish-pending-signup:", err);
    return json({ error: String(err) }, 500);
  }
});

function metaFullName(user: { user_metadata?: Record<string, unknown> }) {
  const n = user.user_metadata?.full_name;
  return n != null ? String(n) : null;
}

async function clearPendingMeta(
  admin: ReturnType<typeof createClient>,
  user: { id: string; user_metadata?: Record<string, unknown> },
) {
  const meta = { ...(user.user_metadata ?? {}) };
  delete meta.pending_professional;
  delete meta.pending_client;
  try {
    await admin.auth.admin.updateUserById(user.id, { user_metadata: meta });
  } catch (e) {
    console.warn("clearPendingMeta:", e);
  }
}
