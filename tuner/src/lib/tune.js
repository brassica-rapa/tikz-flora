// Helpers over the tune tree (lua/flora/tune.lua as JSON) and its _doc
// labels, and the mapping between tune paths and DialKit controls.

export const clone = (o) => JSON.parse(JSON.stringify(o));

export function getPath(obj, path) {
  return path.split(".").reduce((v, k) => (v == null ? undefined : v[k]), obj);
}

export function setPath(obj, path, value) {
  const keys = path.split(".");
  let o = obj;
  for (const k of keys.slice(0, -1)) o = o[k];
  o[keys.at(-1)] = value;
}

export const isRange = (v) => Array.isArray(v) && v.length === 2 && v.every((x) => typeof x === "number");
export const isCurve = (v) =>
  v && typeof v === "object" && !Array.isArray(v) && Array.isArray(v.range) &&
  (Array.isArray(v.points) || Array.isArray(v.weights));

export const docFor = (doc, path) => doc[path] || doc[path.split(".").pop()];
export const labelFor = (doc, path) => (docFor(doc, path) || [path.split(".").pop()])[0];

// Slider bounds by path or, for settings repeated in each folder, by key;
// anything unlisted gets a bound from its value.
const BOUNDS = {
  "gesture.edge": [0.05, 0.6, 0.01], "gesture.bows": [1, 4, 1],
  "gesture.bow_amp": [0, 0.7, 0.01], "gesture.bow_width": [0.2, 1.0, 0.01],
  "gesture.density_floor": [0, 1, 0.01],
  "gesture.bow_density": [0, 1, 0.01],
  "gesture.end_reach": [1, 6, 0.1],
  "plant.root": [0.4, 0.9, 0.01], "plant.lookahead": [8, 120, 1], "plant.bend_radius": [10, 120, 1],
  "plant.bend_ease": [5, 120, 1], "plant.long_shoots": [0, 5, 1],
  "plant.shoot_start": [-0.5, 1, 0.01], "plant.shoot_end": [0, 1, 0.01], "plant.shoot_reach": [0, 0.5, 0.01],
  "plant.shoot_wave": [60, 400, 5], "plant.shoot_bend": [5, 60, 1], "plant.root_width": [1, 8, 0.1],
  "plant.tip_width": [0.4, 3, 0.05], "plant.fork_ratio": [0.2, 0.9, 0.01],
  "plant.foot_shoots": [0, 10, 1], "plant.foot_reach": [20, 160, 1],
  "plant.stem_l": [0.1, 0.8, 0.01], "plant.stem_brush": [0, 1, 0.01],
  "hero.petals": [3, 9, 1], "hero.petal_width": [0.15, 0.7, 0.01], "hero.rotation": [-1, 360, 1],
  "hero.lost_edges": [0, 0.8, 0.01], "hero.tilt": [0, 70, 1],
  "compose.hero": [0.25, 0.7, 0.01], "compose.features": [0.5, 1.6, 0.01],
  "compose.leaves": [0, 160, 1], "compose.leaf_size": [0.5, 1.8, 0.01], "compose.leaf_width": [0.1, 0.45, 0.01],
  "compose.sprays": [0, 250, 1], "compose.small_blooms": [0, 15, 1],
  "compose.curls": [0, 3, 0.05], "compose.leaflet_spacing": [8, 80, 1],
  "compose.leaflet_size": [6, 24, 0.5], "compose.leaf_overlap": [0, 0.95, 0.01],
  "compose.leaf_spacing": [12, 80, 1], "compose.hole_min": [3, 20, 0.5],
  "color.hue": [220, 300, 1], "color.hue_jitter": [0, 30, 1], "color.hue_drift": [-60, 30, 1],
  "wash.blotches": [0, 8, 1], "wash.lifts": [0, 4, 1],
  "wash.blotch_hue": [0, 40, 1], "wash.streak_scale": [0, 1.5, 0.05],
  "wash.lost_edges": [0, 0.8, 0.01], "wash.lost_fade": [0, 2, 0.05],
  base_l: [0.2, 1, 0.01], tip_l: [0.1, 1, 0.01], chroma: [0, 1, 0.01], curve: [0.2, 3, 0.05],
  weight: [0, 10, 0.1], petals: [3, 9, 1], width: [0.15, 0.9, 0.01], ragged: [0, 0.3, 0.01],
  spacing: [0, 0.4, 0.01], rim: [0, 0.4, 0.01], rays: [0, 80, 1], ray_reach: [0, 1, 0.01],
  ray_contrast: [0, 1, 0.01], veins: [0, 40, 1],
};

// Bounds sent with the tune tree (tools/tune_json.lua), by path.
let sent = {};
export function setBounds(b) { sent = b || {}; }

function bounds(path, v) {
  return sent[path] || BOUNDS[path] || BOUNDS[path.split(".").pop()] ||
    (Math.abs(v) <= 1 ? [0, 1, 0.01] : [0, Math.ceil(Math.abs(v) * 2), 0.1]);
}

// Choice lists from tools/tune_json.lua, keyed by parent path.
let lists = {};
export function setChoices(c) { lists = c || {}; }

// Choices for settings that name something.
export function choices(tune, path) {
  if (path === "hero.style") return Object.keys(tune.blooms);
  if (path === "gilt_env") return Object.keys(tune.gilt_looks);
  const parent = path.split(".").slice(0, -1).join(".");
  return lists[parent] || null;
}

const RANGE = { min: "Lowest", max: "Highest" };

// A DialKit config for the tune settings at `paths`, and the entries that
// map each control (its DialKit path) back to a tune path and, for a
// {min, max} range, an index. Labels come from _doc; a label already used
// in the same folder gets its parent's label appended, in lower case (DialKit
// breaks a label before each capital). Curves are left to the curve editor.
export function buildPanel(tune, doc, paths) {
  const entries = [];
  const config = {};
  const unique = (cfg, label, path) => {
    if (!(label in cfg)) return label;
    const parent = path.split(".").slice(0, -1).join(".");
    let l = `${label} (${(parent ? labelFor(doc, parent) : path).toLowerCase()})`;
    for (let i = 2; l in cfg; i++) l = `${label} ${i}`;
    return l;
  };
  const add = (cfg, dial, path, v, depth) => {
    const label = unique(cfg, labelFor(doc, path), path);
    const d = dial ? `${dial}.${label}` : label;
    if (typeof v === "number") {
      const [lo, hi, step] = bounds(path, v);
      cfg[label] = [v, Math.min(lo, v), Math.max(hi, v), step];
      entries.push({ dial: d, path });
    } else if (typeof v === "string") {
      const options = choices(tune, path) || [v];
      cfg[label] = { type: "select", options, default: v };
      entries.push({ dial: d, path });
    } else if (isRange(v)) {
      const [lo, hi, step] = bounds(path, v[0]);
      cfg[label] = {
        [RANGE.min]: [v[0], Math.min(lo, v[0]), Math.max(hi, v[0]), step],
        [RANGE.max]: [v[1], Math.min(lo, v[1]), Math.max(hi, v[1]), step],
        _collapsed: true,
      };
      entries.push({ dial: `${d}.${RANGE.min}`, path, index: 0 });
      entries.push({ dial: `${d}.${RANGE.max}`, path, index: 1 });
    } else if (isCurve(v) || Array.isArray(v)) {
      // edited as a curve, or not editable as a dial
    } else if (v && typeof v === "object") {
      const sub = {};
      for (const [k, x] of Object.entries(v)) add(sub, d, `${path}.${k}`, x, depth + 1);
      if (Object.keys(sub).length) cfg[label] = { ...sub, _collapsed: depth > 0 };
    }
  };
  for (const p of paths) add(config, "", p, getPath(tune, p), 0);
  return { config, entries };
}

// Write DialKit values into the tune tree; returns whether anything changed.
export function applyDials(tune, entries, values) {
  let changed = false;
  for (const e of entries) {
    const v = getPath(values, e.dial);
    if (v === undefined) continue;
    if (e.index !== undefined) {
      const r = getPath(tune, e.path);
      if (r[e.index] !== v) { r[e.index] = v; changed = true; }
    } else if (getPath(tune, e.path) !== v) {
      setPath(tune, e.path, v);
      changed = true;
    }
  }
  return changed;
}

// Every curve (size distribution) under `paths`, as [path, curve] pairs.
export function curvesIn(tune, paths) {
  const out = [];
  const walk = (path, v) => {
    if (isCurve(v)) out.push(path);
    else if (v && typeof v === "object" && !Array.isArray(v)) {
      for (const [k, x] of Object.entries(v)) walk(`${path}.${k}`, x);
    }
  };
  for (const p of paths) walk(p, getPath(tune, p));
  return out;
}

// Every setting under `paths` with its label and description, for the
// guide beside the dials.
export function describe(tune, doc, paths) {
  const out = [];
  const walk = (path, v, depth) => {
    const [label, text] = docFor(doc, path) || [path.split(".").pop(), ""];
    const folder = v && typeof v === "object" && !Array.isArray(v) && !isCurve(v);
    out.push({ path, label, text, depth, folder, curve: isCurve(v), range: isRange(v) });
    if (folder) for (const [k, x] of Object.entries(v)) walk(`${path}.${k}`, x, depth + 1);
  };
  for (const p of paths) walk(p, getPath(tune, p), 0);
  return out;
}
