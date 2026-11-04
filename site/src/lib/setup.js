// The \florasetup line for a mixer state: only what differs from the
// defaults, so it reads like something a person would write.
export function setupLine({ layout, seed, mix, ornaments = {}, palette, spin, gilt, giltenv, giltlook = {}, backdrop }, meta) {
  const parts = [`layout=${layout}`, `seed=${seed}`];
  const defaults = Object.fromEntries(meta.kinds.map(([k, , , d]) => [k, d]));
  const changed = Object.entries(mix).filter(([k, v]) => k !== "density" && v !== defaults[k]);
  if (mix.density !== undefined && mix.density !== defaults.density) parts.push(`density=${mix.density}`);
  if (changed.length) parts.push(`mix={${changed.map(([k, v]) => `${k}=${v}`).join(", ")}}`);
  const ornDefaults = Object.fromEntries((meta.ornaments ?? []).flatMap((s) => s.kinds.map(([k, , d]) => [k, d])));
  const orn = Object.entries(ornaments).filter(([k, v]) => v !== ornDefaults[k]);
  if (orn.length) parts.push(`ornaments={${orn.map(([k, v]) => `${k}=${v}`).join(", ")}}`);
  // The palette as the colourway it is closest to, when naming one saves
  // writing parts out, and the parts that differ from it.
  const partDefaults = Object.fromEntries(meta.parts);
  const differ = (base) => Object.entries(palette).filter(([k, v]) => v !== base[k]);
  let way = null, pal = differ(partDefaults);
  for (const [name, inks] of Object.entries(meta.colourways ?? {})) {
    const d = differ({ ...partDefaults, ...inks });
    if (d.length + 1 < pal.length + (way ? 1 : 0)) [way, pal] = [name, d];
  }
  if (way) parts.push(`colourway=${way}`);
  if (pal.length) parts.push(`palette={${pal.map(([k, v]) => `${k}=${v}`).join(", ")}}`);
  if (spin && Object.values(palette).includes("random")) parts.push(`spin=${spin}`);
  const g = meta.catalog?.gilt;
  if (g && gilt && gilt !== g.default) parts.push(`gilt=${gilt}`);
  if (g && gilt !== "vector") {
    if (giltenv && giltenv !== g.env) parts.push(`giltenv=${giltenv}`);
    const look = Object.entries(giltlook);
    if (look.length) parts.push(`giltlook={${look.map(([k, v]) => `${k}=${v}`).join(", ")}}`);
  }
  if (backdrop && backdrop !== "light") parts.push(`backdrop=${backdrop}`);
  return `\\florasetup{${parts.join(", ")}}`;
}

// Page margins that leave the flora room, by layout.
const GEOMETRY = {
  left: "a4paper,left=5.5cm,right=2cm,top=3.5cm,bottom=3.5cm",
  right: "a4paper,left=2cm,right=5.5cm,top=3.5cm,bottom=3.5cm",
  split: "a4paper,twoside,inner=2cm,outer=5.5cm,top=3.5cm,bottom=3.5cm",
  centered: "a4paper,left=4.6cm,right=4.6cm,top=3.5cm,bottom=3.5cm",
  title: "a4paper,margin=3.2cm,top=5cm",
  surround: "a4paper,margin=3.2cm",
  flank: "a4paper,margin=2.5cm",
  wreath: "a4paper,margin=2.5cm",
  bouquet: "a4paper,margin=2.5cm",
  scrollwork: "a4paper,margin=2.5cm",
};

// The title-page layouts after engraved title pages: a whole title page,
// lettered with \floraletters, with the text on the next page.
export const TITLE_PAGES = new Set(["flank", "wreath", "bouquet", "scrollwork"]);

// The arches the mixer offers for the lettering, in degrees, each baked
// (just site-bake).
export const ARCHES = [[0, "Straight"], [20, "Gentle arch"], [40, "Strong arch"]];

// \floraletters options for the mixer's lettering choice.
export function letterOptions({ style = "engraved", arch = 20, ink = "black" } = {}) {
  return `style=${style}, arch=${arch}` + (ink && ink !== "black" ? `, ink=${ink}` : "");
}

// A whole document that compiles with LuaLaTeX beside the unzipped
// package and shows the mixer's settings on its first page; a title-page
// layout's title is lettered as `letters` asks.
// `ground` ("#rrggbb"), for a dark backdrop, is also given the page and
// its text is set light, so the document compiles as the mixer shows it.
export function documentFor(line, layout, letters, ground) {
  const body = TITLE_PAGES.has(layout)
    ? [
      "\\thispagestyle{empty}",
      "\\vspace*{\\fill}",
      "\\begin{floratitle}",
      "\\centering",
      `{\\fontsize{40}{46}\\selectfont\\floraletters[${letterOptions(letters)}]{FLORILEGIUM}\\par}`,
      "\\vspace{1em}",
      "{\\large\\itshape Of leaves, after Vitruvius and Asa Gray\\par}",
      "\\end{floratitle}",
      "\\vspace*{\\fill}",
      "\\clearpage",
      "\\floraoff",
      "\\section{A first garden}",
      "",
    ].join("\n")
    : layout === "title"
      ? "\\begin{floratitle}\n\\centering\n{\\Huge\\scshape Florilegium\\par}\n\\end{floratitle}\n"
      : "\\section{A first garden}\n";
  return [
    "% Save as main.tex beside tikzflora.sty and lua/, then run: lualatex main",
    "\\documentclass[11pt]{article}",
    `\\usepackage[${GEOMETRY[layout] ?? GEOMETRY.left}]{geometry}`,
    "\\usepackage{tikzflora}",
    line,
    ...(ground ? [`\\pagecolor[HTML]{${ground.replace("#", "").toUpperCase()}}\\color{white}`] : []),
    "",
    "\\begin{document}",
    body.trimEnd(),
    "The framework of the leaf consists of wood, a fibrous and tough",
    "material which runs from the stem through the leaf-stalk into the",
    "blade, where it spreads out to form the ribs and veins.",
    "\\end{document}",
    "",
  ].join("\n");
}
