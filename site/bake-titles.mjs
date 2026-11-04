// Writes the mixer's lettered title pages for `just site-bake`: one
// document per title-page layout, lettering style and arch, made by the
// same documentFor() the mixer's "Copy complete document" uses, so the
// page the mixer shows is the page a user compiles. Prints one line per
// document: the mixer page number, the variant name and the file.
//
//   node site/bake-titles.mjs OUTDIR

import { mkdirSync, writeFileSync } from "node:fs";
import { documentFor, TITLE_PAGES, ARCHES } from "./src/lib/setup.js";

const PAGE = { flank: 11, wreath: 12, bouquet: 13, scrollwork: 14 };
const STYLES = ["outline", "shaded", "engraved"];

const out = process.argv[2];
if (!out) throw new Error("usage: node site/bake-titles.mjs OUTDIR");
mkdirSync(out, { recursive: true });
for (const layout of TITLE_PAGES) {
  if (!PAGE[layout]) throw new Error(`no mixer page for ${layout}`);
  for (const style of STYLES) {
    for (const [arch] of ARCHES) {
      const variant = `${PAGE[layout]}-${style}-${arch}`;
      const file = `${out}/${variant}.tex`;
      writeFileSync(file, documentFor(`\\florasetup{layout=${layout}}`, layout, { style, arch }));
      console.log(`${PAGE[layout]} ${variant} ${file}`);
    }
  }
}
