/**
 * Worker SPA + Open Graph para crawlers (WhatsApp, Facebook, etc.).
 * Sirve meta por ficha en /companies/:id y /companies/:id/review.
 * El resto se delega a los assets de Flutter (SPA).
 *
 * Vars/secrets:
 *   SUPABASE_URL
 *   SUPABASE_ANON_KEY  (publishable / anon)
 */

const BOT_UA =
  /whatsapp|facebookexternalhit|facebot|twitterbot|linkedinbot|slackbot|discordbot|telegrambot|skypeuripreview|googlebot|bingbot|applebot|pinterest|redditbot|embedly|quora link preview|outbrain|vkshare|w3c_validator/i;

const COMPANY_PATH =
  /^\/companies\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:\/review)?\/?$/i;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const ua = request.headers.get("user-agent") || "";
    const match = url.pathname.match(COMPANY_PATH);

    if (match && BOT_UA.test(ua) && env.SUPABASE_URL && env.SUPABASE_ANON_KEY) {
      try {
        const html = await buildOgHtml({
          env,
          origin: url.origin,
          professionalId: match[1],
          isReview: /\/review\/?$/i.test(url.pathname),
          canonicalPath: url.pathname.replace(/\/$/, "") || url.pathname,
        });
        if (html) {
          return new Response(html, {
            status: 200,
            headers: {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "public, max-age=300",
            },
          });
        }
      } catch (e) {
        console.error("[og-spa]", e);
      }
    }

    // Assets SPA (Flutter).
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }
    return new Response("Not found", { status: 404 });
  },
};

async function buildOgHtml({ env, origin, professionalId, isReview, canonicalPath }) {
  const endpoint =
    `${env.SUPABASE_URL.replace(/\/$/, "")}/rest/v1/professionals` +
    `?id=eq.${encodeURIComponent(professionalId)}` +
    `&select=name,profession,city,description,profile_photo,rating,review_count` +
    `&deleted_at=is.null` +
    `&limit=1`;

  const res = await fetch(endpoint, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      Accept: "application/json",
    },
  });

  if (!res.ok) return null;
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;

  const p = rows[0];
  const name = escapeHtml(String(p.name || "Profesional").trim() || "Profesional");
  const profession = escapeHtml(
    String(p.profession || "Profesional del hogar").trim(),
  );
  const city = escapeHtml(String(p.city || "").trim());
  const rating = Number(p.rating || 0);
  const reviews = Number(p.review_count || 0);
  const photo = absoluteUrl(
    origin,
    String(p.profile_photo || "").trim() || `${origin}/favicon.png`,
  );
  const pageUrl = `${origin}${canonicalPath.startsWith("/") ? canonicalPath : `/${canonicalPath}`}`;

  const title = isReview
    ? `Valora a ${name} en miProfio.es`
    : `${name} · ${profession} en miProfio.es`;

  const descParts = [];
  if (isReview) {
    descParts.push(
      `¿Has trabajado con ${name}? Déjale una reseña en 1 minuto. Ayudas a subir su ranking y a que más vecinos confíen.`,
    );
  } else {
    descParts.push(`${profession}${city ? ` en ${city}` : ""}.`);
    if (reviews > 0) {
      descParts.push(
        `${rating.toFixed(1)} ★ · ${reviews} reseña${reviews === 1 ? "" : "s"}.`,
      );
    } else {
      descParts.push("Sé el primero en valorar su trabajo.");
    }
    descParts.push("Contacta y compara en miProfio.es.");
  }
  const description = escapeHtml(descParts.join(" "));

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <meta name="description" content="${description}">
  <link rel="canonical" href="${escapeHtml(pageUrl)}">
  <meta property="og:type" content="profile">
  <meta property="og:site_name" content="miProfio.es">
  <meta property="og:locale" content="es_ES">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${description}">
  <meta property="og:url" content="${escapeHtml(pageUrl)}">
  <meta property="og:image" content="${escapeHtml(photo)}">
  <meta property="og:image:alt" content="${name}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${escapeHtml(photo)}">
  <meta http-equiv="refresh" content="0;url=${escapeHtml(pageUrl)}">
</head>
<body>
  <p><a href="${escapeHtml(pageUrl)}">${title}</a></p>
</body>
</html>`;
}

function absoluteUrl(origin, value) {
  if (!value) return `${origin}/favicon.png`;
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  if (value.startsWith("/")) return `${origin}${value}`;
  return value;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
