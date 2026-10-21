/**
 * Pruebas mínimas del matching SEO de ciudad (sin Wrangler).
 * Uso: node workers/city_match.test.mjs
 */
import {
  cityMatchesSeoLocation,
  primaryCitySegment,
  slugify,
} from "./city_match.js";

let failed = 0;

function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

assert(slugify("Madrid") === "madrid", "slugify Madrid");
assert(slugify("Madrigal de la Vera") === "madrigal-de-la-vera", "slugify Madrigal");

assert(primaryCitySegment("Madrid, Comunidad de Madrid") === "Madrid", "primary Madrid+CA");
assert(
  primaryCitySegment("Segovia,Madrid , Norte de España y península") === "Segovia",
  "primary multi Segovia primero",
);
assert(primaryCitySegment("") === "", "primary vacío");

assert(
  cityMatchesSeoLocation("Madrid", "Madrid") === true,
  "exact Madrid",
);
assert(
  cityMatchesSeoLocation("Madrid, Comunidad de Madrid", "Madrid") === true,
  "Madrid + provincia (primario Madrid)",
);
assert(
  cityMatchesSeoLocation("Parla, Comunidad de Madrid", "Madrid") === false,
  "Parla no es landing Madrid (antes: includes comunidad-de-madrid)",
);
assert(
  cityMatchesSeoLocation(
    "Segovia,Madrid , Norte de España y península",
    "Madrid",
  ) === false,
  "multi con Madrid secundario no cuenta (primario Segovia)",
);
assert(
  cityMatchesSeoLocation("Madrigal de la Vera", "Madrid") === false,
  "madrigal ⊄ madrid",
);
assert(
  cityMatchesSeoLocation("Madrid", "Madrigal de la Vera") === false,
  "madrid ⊄ madrigal landing",
);
assert(
  cityMatchesSeoLocation("Candeleda", "Candeleda") === true,
  "La Vera Candeleda exact",
);
assert(
  cityMatchesSeoLocation("Candeleda, Ávila", "Candeleda") === true,
  "Candeleda + provincia",
);
assert(
  cityMatchesSeoLocation("Villanueva de la Vera", "Candeleda") === false,
  "otro pueblo La Vera no mezcla",
);
assert(cityMatchesSeoLocation("", "Madrid") === false, "vacío excluido");
assert(cityMatchesSeoLocation("   ", "Madrid") === false, "blank excluido");
assert(
  cityMatchesSeoLocation(null, "Madrid") === false,
  "null excluido",
);
assert(
  cityMatchesSeoLocation("madrid-centro", "Madrid") === true,
  "prefijo frontera madrid-centro",
);

if (failed > 0) {
  console.error(`\n${failed} assertion(s) failed`);
  process.exit(1);
}
console.log("\nAll city_match tests passed.");
