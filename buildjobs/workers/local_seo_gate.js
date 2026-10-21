/**
 * Cuándo servir HTML SEO de hubs/landings vs SPA Flutter.
 * P0-1: landings LocalSeo para TODOS los UA; ?app=1 / ?spa=1 → SPA.
 */

export const LOCAL_SEO_PATH =
  /^\/(madrid|candeleda|madrigal-de-la-vera|villanueva-de-la-vera)(?:\/([a-z0-9-]+))?\/?$/i;

/** Bypass explícito hacia la PWA (mismo path, query). */
export function wantsFlutterApp(url) {
  const v = url.searchParams.get("app") ?? url.searchParams.get("spa");
  return v === "1" || v === "true";
}

export function shouldServeLocalSeoHtml(url) {
  return LOCAL_SEO_PATH.test(url.pathname) && !wantsFlutterApp(url);
}
