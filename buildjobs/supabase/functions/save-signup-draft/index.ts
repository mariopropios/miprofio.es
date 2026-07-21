// ── save-signup-draft ─────────────────────────────────────────────────────────
// Guarda el borrador ANTES de confirmar email (sin sesión).
// 1) Upsert texto SIEMPRE (aunque fallen las fotos).
// 2) Sube fotos y actualiza URLs si se puede.
// 3) Copia el payload de texto en user_metadata (fallback cross-browser).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type DraftKind = "professional" | "client";

type RequestBody = {
  userId?: string;
  kind?: DraftKind;
  payload?: Record<string, unknown>;
  avatarBase64?: string | null;
  avatarMime?: string;
  galleryBase64?: string[];
  galleryMimes?: string[];
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function extFromMime(mime: string): string {
  if (mime.includes("png")) return "png";
  if (mime.includes("webp")) return "webp";
  if (mime.includes("gif")) return "gif";
  return "jpg";
}

function decodeBase64(data: string): Uint8Array {
  const cleaned = data.includes(",") ? data.split(",").pop()! : data;
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Limita tamaño de foto en Edge (~1.5MB base64 ≈ ~1MB binario). */
function canUploadBase64(b64: string | null | undefined): boolean {
  if (!b64) return false;
  return b64.length > 0 && b64.length < 1_800_000;
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
    const kind = body.kind;
    const payload = body.payload ?? {};

    if (!userId || (kind !== "professional" && kind !== "client")) {
      return json({ error: "Faltan userId o kind." }, 400);
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
      return json({ error: "Usuario no encontrado." }, 404);
    }

    const textPayload: Record<string, unknown> = { ...payload };
    delete textPayload.avatarBase64;
    delete textPayload.galleryBase64;
    delete textPayload.avatarBytes;
    delete textPayload.galleryBytes;

    // 1) Guardar texto YA (crítico para Gmail → Safari).
    const { error: upsertError } = await admin.from("signup_drafts").upsert(
      {
        user_id: userId,
        kind,
        payload: textPayload,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );

    if (upsertError) {
      console.error("signup_drafts upsert:", upsertError);
      return json({ error: upsertError.message }, 500);
    }

    // Metadata Auth: sobrevive aunque falle storage / otra capa.
    const metaKey = kind === "professional"
      ? "pending_professional"
      : "pending_client";
    try {
      await admin.auth.admin.updateUserById(userId, {
        user_metadata: {
          ...(userData.user.user_metadata ?? {}),
          role: kind === "professional" ? "professional" : "client",
          [metaKey]: textPayload,
        },
      });
    } catch (metaErr) {
      console.warn("metadata update failed:", metaErr);
    }

    const savedPayload: Record<string, unknown> = { ...textPayload };
    const stamp = Date.now();
    let photoErrors = 0;

    if (canUploadBase64(body.avatarBase64 ?? undefined)) {
      try {
        const mime = body.avatarMime || "image/jpeg";
        const bytes = decodeBase64(body.avatarBase64!);
        const path = `${userId}/draft-avatar-${stamp}.${extFromMime(mime)}`;
        const { error: upErr } = await admin.storage
          .from("profile-photos")
          .upload(path, bytes, { contentType: mime, upsert: true });
        if (!upErr) {
          const { data: pub } = admin.storage
            .from("profile-photos")
            .getPublicUrl(path);
          savedPayload.profilePhotoUrl = `${pub.publicUrl}?v=${stamp}`;
        } else {
          photoErrors++;
          console.warn("avatar upload:", upErr);
        }
      } catch (e) {
        photoErrors++;
        console.warn("avatar decode/upload:", e);
      }
    }

    const galleryUrls: string[] = [];
    const galleryB64 = body.galleryBase64 ?? [];
    const galleryMimes = body.galleryMimes ?? [];
    const maxGallery = Math.min(galleryB64.length, 4);
    for (let i = 0; i < maxGallery; i++) {
      const raw = galleryB64[i];
      if (!canUploadBase64(raw)) continue;
      try {
        const mime = galleryMimes[i] || "image/jpeg";
        const bytes = decodeBase64(raw);
        const path =
          `${userId}/draft-gallery-${stamp}-${i}.${extFromMime(mime)}`;
        const { error: upErr } = await admin.storage
          .from("profile-photos")
          .upload(path, bytes, { contentType: mime, upsert: true });
        if (!upErr) {
          const { data: pub } = admin.storage
            .from("profile-photos")
            .getPublicUrl(path);
          galleryUrls.push(`${pub.publicUrl}?v=${stamp}`);
        } else {
          photoErrors++;
        }
      } catch (_) {
        photoErrors++;
      }
    }
    if (galleryUrls.length > 0) {
      savedPayload.galleryPhotoUrls = galleryUrls;
      if (!savedPayload.profilePhotoUrl) {
        savedPayload.profilePhotoUrl = galleryUrls[0];
      }
    }

    if (savedPayload.profilePhotoUrl || galleryUrls.length > 0) {
      await admin.from("signup_drafts").upsert(
        {
          user_id: userId,
          kind,
          payload: savedPayload,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );
    }

    return json({
      ok: true,
      kind,
      hasPhoto: Boolean(savedPayload.profilePhotoUrl),
      galleryCount: galleryUrls.length,
      photoErrors,
    });
  } catch (err) {
    console.error("save-signup-draft:", err);
    return json({ error: String(err) }, 500);
  }
});
