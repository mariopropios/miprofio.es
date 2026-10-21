/**
 * Uso: node workers/local_seo_gate.test.mjs
 */
import {
  LOCAL_SEO_PATH,
  shouldServeLocalSeoHtml,
  wantsFlutterApp,
} from "./local_seo_gate.js";

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

assert(LOCAL_SEO_PATH.test("/madrid/fontanero"), "path madrid oficio");
assert(LOCAL_SEO_PATH.test("/madrigal-de-la-vera"), "path madrigal hub");
assert(!LOCAL_SEO_PATH.test("/search"), "path search no local");
assert(!LOCAL_SEO_PATH.test("/login"), "path login no local");

assert(
  shouldServeLocalSeoHtml(new URL("https://miprofio.es/madrid/fontanero")),
  "SEO html sin query",
);
assert(
  shouldServeLocalSeoHtml(new URL("https://miprofio.es/madrid")),
  "SEO html hub",
);
assert(
  !shouldServeLocalSeoHtml(
    new URL("https://miprofio.es/madrid/fontanero?app=1"),
  ),
  "bypass app=1",
);
assert(
  !shouldServeLocalSeoHtml(
    new URL("https://miprofio.es/candeleda?spa=1"),
  ),
  "bypass spa=1",
);
assert(
  !shouldServeLocalSeoHtml(new URL("https://miprofio.es/search")),
  "search no SEO local",
);
assert(
  wantsFlutterApp(new URL("https://miprofio.es/madrid?app=true")),
  "app=true cuenta",
);

if (failed) {
  console.error(`\n${failed} failed`);
  process.exit(1);
}
console.log("\nAll local_seo_gate tests passed.");
