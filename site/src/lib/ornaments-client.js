// The site's own page ornaments (Ornament.svelte): one worker for the
// page draws each with the package's engine, in the margins' inks, and
// the dials (dials.js) can choose the kind each slot shows.
import { gardenAt } from "./garden.js";
import { client, rgbOf } from "./margins-client.js";
import { TUNE } from "./margins.js";

let worker = null;
const chosen = {};
const listeners = new Set();

// Draw a `slot` ornament w x h CSS px: kind `name`, else the dials' choice
// for the slot, else one picked from `seed` and the day's garden.
// Resolves with { bitmap, name }.
export function drawOrnament({ slot, name, seed, w, h }) {
  worker ??= client();
  const at = gardenAt();
  const dpr = Math.min(2, Math.max(1, window.devicePixelRatio || 1));
  return worker.post({
    kind: "ornament", slot, name: name ?? chosen[slot], seed: at.seed * 16 + seed, w, h, dpr,
    colourway: TUNE.colourway, paper: rgbOf(getComputedStyle(document.body).backgroundColor),
  });
}

// Show kind `name` in every `slot` ornament (undefined: each its own).
export function choose(slot, name) {
  if (chosen[slot] === name) return;
  chosen[slot] = name;
  for (const f of listeners) f(slot);
}

// Call f(slot) when the kind chosen for a slot changes; returns the unsubscribe.
export function onChoose(f) {
  listeners.add(f);
  return () => listeners.delete(f);
}
