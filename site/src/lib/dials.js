// The margin garden's dials (DialKit): the front's lead (how far ahead of
// the reader it grows, so how big a gap it leaves above the viewport's
// foot), its softness and speed, and the inks. Loaded when the gear in the
// page's corner is first pressed (Shell.svelte), so visitors who never
// press it never download it. Values persist in this browser; DialKit's
// Copy puts them on the clipboard to bake in (margins.js TUNE).
import { createDialKit, createDialRoot } from "dialkit/vanilla";
import "dialkit/vanilla/styles.css";
import { inks } from "@alpaca-software/web-flora/engine";
import { TUNE } from "./margins.js";

// The parts a colourway inks (inks.ts COLOURWAYS).
const PARTS = ["hero", "blooms", "leaves", "leaflets", "stems", "sprays", "ghost", "cartouche"];
// An ink select's first option: whatever the colourway gives that part.
const OWN = "colourway's";

let root = null, kit = null;

// Open the dials on `garden` (startMargins), or close them if open.
export function toggleDials(garden) {
  if (kit) {
    kit.setOpen(!kit.getOpen());
    return;
  }
  const way = garden.tuning.colourway;
  // Labelled as written: DialKit title-cases bare option strings.
  const inkOptions = [{ value: OWN, label: "From colourway" }, ...inks.ORDER.map((n) => ({ value: n, label: n }))];
  const config = {
    front: {
      lead: [TUNE.lead, 0.3, 1, 0.01],
      soft: [TUNE.soft, 10, 240, 1],
      slow: [TUNE.slow, 20, 600, 5],
      catch: [TUNE.catch, 0.1, 3, 0.05],
      top: [TUNE.top, 100, 4000, 10],
      ease: [TUNE.ease, 0, 4, 0.05],
    },
    inks: {
      colourway: { type: "select", options: inks.COLOURWAY_ORDER.map((n) => ({ value: n, label: n })), default: inks.COLOURWAY_ALIAS[way] ?? way },
      ...Object.fromEntries(PARTS.map((p) => [p, { type: "select", options: inkOptions, default: OWN }])),
    },
    regrow: { type: "action" },
  };
  root = createDialRoot({ position: "bottom-right", defaultOpen: true, productionEnabled: true, theme: "light" });
  // Not page content: the garden measures the margins without it.
  root.element.dataset.floraUi = "";
  kit = createDialKit("Margins", config, { persist: { key: "flora-margins-dials" }, onAction: (a) => { if (a === "regrow") garden.regrow(); } });
  kit.subscribe((v) => {
    const own = {};
    for (const p of PARTS) if (v.inks[p] && v.inks[p] !== OWN) own[p] = v.inks[p];
    garden.tune({ ...v.front, colourway: v.inks.colourway, inks: own });
  });
}

// Remove the dials (the page is leaving).
export function closeDials() {
  kit?.destroy();
  root?.destroy();
  kit = root = null;
}
