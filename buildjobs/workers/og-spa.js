/**
 * Worker SPA + Open Graph / SEO local para crawlers.
 * - /companies/:id(+ /review) → OG de ficha
 * - /{candeleda|madrigal-de-la-vera|villanueva-de-la-vera}[/{oficio}] → HTML SEO
 * El resto → assets Flutter (SPA).
 *
 * Vars: SUPABASE_URL, SUPABASE_ANON_KEY
 */

const BOT_UA =
  /whatsapp|facebookexternalhit|facebot|twitterbot|linkedinbot|slackbot|discordbot|telegrambot|skypeuripreview|googlebot|bingbot|applebot|pinterest|redditbot|embedly|quora link preview|outbrain|vkshare|w3c_validator/i;

const COMPANY_PATH =
  /^\/companies\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:\/review)?\/?$/i;

const LOCAL_SEO_PATH =
  /^\/(candeleda|madrigal-de-la-vera|villanueva-de-la-vera)(?:\/([a-z0-9-]+))?\/?$/i;

/** Keep in sync with lib/core/constants/local_seo.dart */
const LOCAL_SEO_CITIES = {
  candeleda: {
    name: "Candeleda",
    regionLabel: "La Vera",
    provinceHint: "Ávila",
  },
  "madrigal-de-la-vera": {
    name: "Madrigal de la Vera",
    regionLabel: "La Vera",
    provinceHint: "Cáceres",
  },
  "villanueva-de-la-vera": {
    name: "Villanueva de la Vera",
    regionLabel: "La Vera",
    provinceHint: "Cáceres",
  },
};

/** Keep in sync with ProfessionCatalog.allProfessions names */
const LOCAL_SEO_PROFESSIONS = [
  "Fontanero",
  "Electricista",
  "Cerrajero",
  "Reparación de Electrodomésticos",
  "Climatización",
  "Gasista",
  "Antenista",
  "Pocero",
  "Impermeabilizador",
  "Instalador Solar",
  "Herrero",
  "Instalador de Baños",
  "Instalador de Cocinas",
  "Albañil",
  "Pintor",
  "Carpintero (Madera)",
  "Pladurista",
  "Escayolista",
  "Ventanas y Cerramientos",
  "Alicatador",
  "Parquetista",
  "Cristalero",
  "Techador",
  "Mampostero",
  "Desescombro",
  "Solador",
  "Hormigón impreso",
  "Andamiero",
  "Manitas a domicilio",
  "Limpieza Fin de Obra",
  "Jardinero",
  "Persianista",
  "Piscina",
  "Limpia-Cristales",
  "Desbrozador",
  "Control de Plagas",
  "Técnico de Ascensores",
  "Instalador de Riego",
  "Arquitecto",
  "Arquitecto técnico",
  "Diseñador de interiores",
  "Decorador",
  "Paisajista",
  "Delineante",
  "Diseñador de iluminación",
  "Consultor energético",
];

const PROFESSION_SLUG_ALIASES = {
  aparejador: "arquitecto-tecnico",
  "arquitecto-tecnico-aparejador": "arquitecto-tecnico",
  interiorista: "disenador-de-interiores",
  "disenadora-de-interiores": "disenador-de-interiores",
  fontaneria: "fontanero",
  electricidad: "electricista",
  albanileria: "albanil",
};

const PROFESSION_BY_SLUG = (() => {
  const map = Object.create(null);
  for (const name of LOCAL_SEO_PROFESSIONS) {
    map[slugify(name)] = name;
  }
  for (const [alias, canonical] of Object.entries(PROFESSION_SLUG_ALIASES)) {
    if (map[canonical]) map[alias] = map[canonical];
  }
  return map;
})();

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (
      url.hostname === "profio-web.mariopropiosplaza.workers.dev" ||
      url.hostname.endsWith(".profio-web.mariopropiosplaza.workers.dev")
    ) {
      const dest = new URL(
        url.pathname + url.search + url.hash,
        "https://miprofio.es",
      );
      return Response.redirect(dest.toString(), 302);
    }

    const ua = request.headers.get("user-agent") || "";
    const isBot = BOT_UA.test(ua);

    const companyMatch = url.pathname.match(COMPANY_PATH);
    if (companyMatch && isBot && env.SUPABASE_URL && env.SUPABASE_ANON_KEY) {
      try {
        const html = await buildOgHtml({
          env,
          origin: url.origin,
          professionalId: companyMatch[1],
          isReview: /\/review\/?$/i.test(url.pathname),
          canonicalPath: url.pathname.replace(/\/$/, "") || url.pathname,
        });
        if (html) {
          return htmlResponse(html);
        }
      } catch (e) {
        console.error("[og-spa] company", e);
      }
    }

    const localMatch = url.pathname.match(LOCAL_SEO_PATH);
    if (localMatch && isBot) {
      try {
        const citySlug = localMatch[1];
        const professionSlug = localMatch[2] || null;
        const html = await buildLocalSeoHtml({
          env,
          origin: url.origin,
          citySlug,
          professionSlug,
        });
        if (html) return htmlResponse(html);
      } catch (e) {
        console.error("[og-spa] local-seo", e);
      }
    }

    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }
    return new Response("Not found", { status: 404 });
  },
};

function htmlResponse(html) {
  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
    },
  });
}

async function buildLocalSeoHtml({ env, origin, citySlug, professionSlug }) {
  const city = LOCAL_SEO_CITIES[citySlug];
  if (!city) return null;

  const professionName = professionSlug
    ? PROFESSION_BY_SLUG[slugify(professionSlug)]
    : null;
  if (professionSlug && !professionName) return null;

  const canonicalPath = professionName
    ? `/${citySlug}/${slugify(professionName)}`
    : `/${citySlug}`;
  const pageUrl = `${origin}${canonicalPath}`;

  const title = professionName
    ? `${professionName} en ${city.name} | miProfio.es`
    : `Profesionales del hogar en ${city.name} | miProfio.es`;

  const description = professionName
    ? `Encuentra ${professionName} con reseñas en ${city.name} (${city.regionLabel}). Compara perfiles, distancia y contacta gratis.`
    : `Encuentra fontaneros, electricistas, albañiles y más profesionales del hogar en ${city.name} (${city.regionLabel}). Compara reseñas y contacta gratis en miProfio.es.`;

  const h1 = professionName
    ? `${professionName} en ${city.name}`
    : `Profesionales del hogar en ${city.name}`;

  const intro = professionName
    ? `¿Necesitas un ${professionName} en ${city.name}? En miProfio.es reunimos profesionales de ${city.regionLabel} (${city.provinceHint}) con reseñas de clientes. Contacta gratis o publica tu perfil si ofreces este servicio en la zona.`
    : `Busca oficios de confianza en ${city.name} y alrededores de ${city.regionLabel} (${city.provinceHint}). Compara perfiles con reseñas reales y contacta sin coste de publicación para el profesional.`;

  let pros = [];
  if (professionName && env.SUPABASE_URL && env.SUPABASE_ANON_KEY) {
    pros = await fetchLocalProfessionals({
      env,
      profession: professionName,
      cityName: city.name,
    });
  }

  const popular = [
    "Fontanero",
    "Electricista",
    "Albañil",
    "Pintor",
    "Arquitecto",
    "Diseñador de interiores",
  ];

  const otherCities = Object.entries(LOCAL_SEO_CITIES)
    .filter(([slug]) => slug !== citySlug)
    .map(([slug, c]) => ({ slug, name: c.name }));

  const breadcrumb = professionName
    ? [
        { name: "Inicio", item: `${origin}/` },
        { name: city.name, item: `${origin}/${citySlug}` },
        { name: professionName, item: pageUrl },
      ]
    : [
        { name: "Inicio", item: `${origin}/` },
        { name: city.name, item: pageUrl },
      ];

  const jsonLd = [
    {
      "@context": "https://schema.org",
      "@type": "WebPage",
      name: title,
      description,
      url: pageUrl,
      inLanguage: "es-ES",
      isPartOf: { "@type": "WebSite", name: "miProfio.es", url: origin },
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: breadcrumb.map((b, i) => ({
        "@type": "ListItem",
        position: i + 1,
        name: b.name,
        item: b.item,
      })),
    },
  ];

  if (pros.length > 0) {
    jsonLd.push({
      "@context": "https://schema.org",
      "@type": "ItemList",
      name: h1,
      itemListElement: pros.slice(0, 12).map((p, i) => ({
        "@type": "ListItem",
        position: i + 1,
        url: `${origin}/companies/${p.id}`,
        name: p.name,
      })),
    });
  }

  if (professionName) {
    jsonLd.push({
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: [
        {
          "@type": "Question",
          name: `¿Cómo encontrar un ${professionName} en ${city.name}?`,
          acceptedAnswer: {
            "@type": "Answer",
            text: `En miProfio.es puedes ver perfiles de ${professionName} cerca de ${city.name}, leer reseñas de clientes y contactar gratis. Si ofreces el servicio, publica tu ficha sin coste.`,
          },
        },
        {
          "@type": "Question",
          name: `¿Cuesta publicar un perfil de ${professionName} en ${city.name}?`,
          acceptedAnswer: {
            "@type": "Answer",
            text: "No. Publicar el perfil profesional en miProfio.es es gratis.",
          },
        },
      ],
    });
  }

  const linksProfession = professionName
    ? otherCities
        .map(
          (c) =>
            `<li><a href="${origin}/${c.slug}/${slugify(professionName)}">${escapeHtml(professionName)} en ${escapeHtml(c.name)}</a></li>`,
        )
        .join("")
    : popular
        .map(
          (n) =>
            `<li><a href="${origin}/${citySlug}/${slugify(n)}">${escapeHtml(n)} en ${escapeHtml(city.name)}</a></li>`,
        )
        .join("");

  const resultsHtml =
    pros.length === 0
      ? professionName
        ? `<p>Aún no hay perfiles de ${escapeHtml(professionName)} en ${escapeHtml(city.name)}. <a href="${origin}/register/professional">Sé el primero en publicar gratis</a>.</p>`
        : `<p>Explora oficios en ${escapeHtml(city.name)} o <a href="${origin}/register/professional">publica tu perfil gratis</a>.</p>`
      : `<ul>${pros
          .slice(0, 12)
          .map(
            (p) =>
              `<li><a href="${origin}/companies/${p.id}">${escapeHtml(p.name)}</a> — ${escapeHtml(p.profession || professionName || "")}${p.city ? ` · ${escapeHtml(p.city)}` : ""}</li>`,
          )
          .join("")}</ul>`;

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <link rel="canonical" href="${escapeHtml(pageUrl)}">
  <meta name="robots" content="index, follow">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="miProfio.es">
  <meta property="og:locale" content="es_ES">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${escapeHtml(pageUrl)}">
  <meta property="og:image" content="${origin}/favicon.png">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="${escapeHtml(title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <script type="application/ld+json">${JSON.stringify(jsonLd)}</script>
  <meta http-equiv="refresh" content="0;url=${escapeHtml(pageUrl)}">
</head>
<body>
  <header>
    <p><a href="${origin}/">miProfio.es</a></p>
  </header>
  <main>
    <h1>${escapeHtml(h1)}</h1>
    <p>${escapeHtml(intro)}</p>
    ${resultsHtml}
    <h2>${professionName ? "Mismo oficio en otros pueblos" : `Oficios en ${escapeHtml(city.name)}`}</h2>
    <ul>${linksProfession}</ul>
    <p><a href="${origin}/register/professional">Publicar perfil profesional gratis</a></p>
  </main>
</body>
</html>`;
}

async function fetchLocalProfessionals({ env, profession, cityName }) {
  const endpoint =
    `${env.SUPABASE_URL.replace(/\/$/, "")}/rest/v1/professionals` +
    `?select=id,name,profession,city,rating,review_count` +
    `&profession=ilike.*${encodeURIComponent(profession)}*` +
    `&deleted_at=is.null` +
    `&limit=24`;

  const res = await fetch(endpoint, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      Accept: "application/json",
    },
  });
  if (!res.ok) return [];
  const rows = await res.json();
  if (!Array.isArray(rows)) return [];

  const cityNeedle = slugify(cityName);
  return rows.filter((p) => {
    const city = String(p.city || "");
    if (!city) return true;
    const s = slugify(city);
    return s === cityNeedle || s.startsWith(cityNeedle) || s.includes(cityNeedle);
  });
}

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

function slugify(input) {
  const from = "áàäâãéèëêíìïîóòöôõúùüûñç";
  const to = "aaaaaeeeeiiiiooooouuuunc";
  let out = "";
  const s = String(input || "").trim().toLowerCase();
  for (const ch of s) {
    const idx = from.indexOf(ch);
    if (idx >= 0) out += to[idx];
    else if (/[a-z0-9]/.test(ch)) out += ch;
    else if (/[\s_/.,;:()+\-]/.test(ch)) out += "-";
  }
  return out.replace(/-+/g, "-").replace(/^-|-$/g, "");
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
