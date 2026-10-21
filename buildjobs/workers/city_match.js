/**
 * Matching ciudad para landings SEO locales (Worker).
 * Alineado con LocalSeo.locationByCityName / formatCityWithProvince (Dart):
 * - ciudad vacía → no entra en landings (no inflar ItemList)
 * - ciudad multi («A, B, C») → solo el primer segmento (ciudad primaria)
 * - match: slug exacto o prefijo con frontera `${needle}-`
 *   (madrid ≡ madrid, madrid-centro; NO madrid ⊂ madrigal-de-la-vera;
 *    NO substring en «comunidad-de-madrid» ni en el string completo)
 */

export function slugify(input) {
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

/** Primer segmento antes de coma (ciudad primaria). */
export function primaryCitySegment(cityRaw) {
  const raw = String(cityRaw || "").trim();
  if (!raw) return "";
  const comma = raw.indexOf(",");
  if (comma < 0) return raw;
  return raw.slice(0, comma).trim();
}

/**
 * ¿La ciudad del profesional pertenece a la localidad SEO `locationName`?
 * @param {string|null|undefined} cityRaw valor `professionals.city`
 * @param {string} locationName p.ej. "Madrid" / "Candeleda"
 */
export function cityMatchesSeoLocation(cityRaw, locationName) {
  const primary = primaryCitySegment(cityRaw);
  if (!primary) return false; // vacío → excluir de landings

  const needle = slugify(locationName);
  if (!needle) return false;

  const s = slugify(primary);
  if (!s) return false;

  return s === needle || s.startsWith(`${needle}-`);
}
