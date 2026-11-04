// Runs the tikz-flora generator (lua/flora/*.lua) under wasmoon, Lua 5.4
// in WebAssembly. `just test-lua54` checks it paints exactly what LuaLaTeX
// paints. Messages:
//   { id, kind: "meta" }            -> { id, meta }  settings to offer, with
//                                      each ink's ramp, each group's inks and
//                                      each colourway's palette
//   { id, kind: "render", spec, layout, seed, page, mix, ornaments, palette, spin, px, gilt, giltenv, giltlook, backdrop, draw }
//                                   -> { id, progress } as it goes (0 to 1,
//                                      rising: PROGRESS below), then
//                                      { id, bitmap | pdf, ms }
//   { id, kind: "version" }         -> { id, version }  a hash of the
//                                      generator's sources, for cache keys
//   { id, kind: "garden", garden, px, png, draw }
//                                   -> { id, bitmap, png?, ms }  the flora
//                                      of a web page (lua/flora/garden.lua:
//                                      garden = {mode, width, height, x0,
//                                      x1, seed, grow, settings}), cut to
//                                      its view; with `png`, also as a PNG
//                                      Blob for caching; with `scene`, not
//                                      drawn: -> { id, scene, view, ms },
//                                      the scene JSON and its view
//                                      (tools/renderers.js)
//   { id, kind: "gallery", palette, spin, base, px, slot, gilt, giltenv, giltlook, draw }
//                                   -> { id, bitmap | pdf, cells, slots, w, h }
//                                      every ornament kind (gallery.lua), or
//                                      those of one slot, with where to
//                                      label each and every slot's label
// With `px` (the picture's width in device pixels) the page's content
// stream is drawn here by flora's renderers (draw.js) and returned as an
// ImageBitmap, with `renderer` ("webgl" or "canvas2d") and `drawMs`;
// without it, as PDF bytes for pdf.js. `draw` ("webgl", the default, or
// "canvas2d") asks for one renderer. `gilt` ("raster" or
// "vector") picks how ornament gold is painted, `giltenv` ("studio" or
// "mirror") which look raster gold takes, and `giltlook` ("key=value, ...",
// as \florasetup's giltlook) changes keys of that look; raster gold is
// computed at the picture's own resolution (150 dpi for pdf.js).
// `backdrop` ("light", "dark" or "#rrggbb", as \\florasetup's backdrop)
// is what the picture will be shown over; on a dark one the picture is
// light ink on a transparent ground.
import { LuaFactory } from "wasmoon";
import wasmUrl from "wasmoon/dist/glue.wasm?url";
import { draw } from "./draw.js";

const sources = import.meta.glob("../../../lua/flora/*.lua", { query: "?raw", import: "default", eager: true });

let engine;
async function lua() {
  engine ||= (async () => {
    const factory = new LuaFactory(wasmUrl);
    for (const [path, src] of Object.entries(sources)) {
      await factory.mountFile(`/lua/flora/${path.split("/").pop()}`, src);
    }
    const l = await factory.createEngine();
    await l.doString('package.path = "/lua/?.lua;" .. package.path');
    return l;
  })();
  return engine;
}

// A render's progress at the end of the grow, of the PDF scene and of
// reading it into the drawing's display list; drawing it takes the rest.
const PROGRESS = { grow: 0.7, scene: 0.79, listed: 0.83 };

// A Lua table literal for {name: value}, names checked to be identifiers.
function table(obj) {
  const parts = [];
  for (const [k, v] of Object.entries(obj || {})) {
    if (!/^[a-z_][a-z0-9_]*$/.test(k)) throw new Error(`bad key ${k}`);
    if (typeof v === "number" && Number.isFinite(v)) parts.push(`${k}=${v}`);
    else if (typeof v === "string") parts.push(`${k}=${JSON.stringify(v)}`);
  }
  return `{${parts.join(",")}}`;
}

const META = `
local Tune = require("flora.tune")
local Inks = require("flora.inks")
local Mix = require("flora.mix")
local Orn = require("flora.ornaments")
local function q(s) return '"' .. tostring(s):gsub('[\\\\"]', '\\\\%0') .. '"' end
local function doc(path)
  local d = Tune._doc[path] or {}
  return q(d[1] or path) .. "," .. q(d[2] or "")
end
local kinds = {}
local order = {}
for _, k in ipairs(Mix.motifs) do order[#order + 1] = k end
for _, k in ipairs({ "leaves", "leaflets", "sprays", "curls", "density" }) do order[#order + 1] = k end
for _, k in ipairs(Mix.shapes) do order[#order + 1] = k end
for _, k in ipairs(Mix.styles) do order[#order + 1] = k end
for _, k in ipairs(Mix.visitors) do order[#order + 1] = k end
for _, k in ipairs(order) do
  kinds[#kinds + 1] = "[" .. q(k) .. "," .. doc("mix." .. k) .. "," .. Tune.mix[k] .. "]"
end
local parts = {}
for _, p in ipairs({ "hero", "blooms", "leaves", "leaflets", "stems", "sprays", "ghost", "cartouche" }) do
  parts[#parts + 1] = "[" .. q(p) .. "," .. q(Tune.color.palette[p]) .. "]"
end
local groups, inks, ramps, members = {}, {}, {}, {}
for _, g in ipairs(Inks.group_order) do
  groups[#groups + 1] = q(g)
  local ns = {}
  for _, n in ipairs(Inks.groups[g]) do ns[#ns + 1] = q(n) end
  members[#members + 1] = q(g) .. ":[" .. table.concat(ns, ",") .. "]"
end
for _, n in ipairs(Inks.order) do
  inks[#inks + 1] = q(n)
  local stops = {}
  for _, st in ipairs(Inks.ramps[n]) do
    stops[#stops + 1] = string.format("[%.4f,%.4f,%.4f]", st[1], st[2], st[3])
  end
  ramps[#ramps + 1] = q(n) .. ":[" .. table.concat(stops, ",") .. "]"
end
local ways = {}
for _, name in ipairs(Inks.colourway_order) do
  local cw = Inks.colourways[name]
  if cw then
    local ps = {}
    for _, p in ipairs({ "hero", "blooms", "leaves", "leaflets", "stems", "sprays", "ghost", "cartouche" }) do
      ps[#ps + 1] = q(p) .. ":" .. q(cw[p])
    end
    ways[#ways + 1] = q(name) .. ":{" .. table.concat(ps, ",") .. "}"
  end
end
local slots = {}
for _, slot in ipairs(Orn.slot_order) do
  local ks = {}
  for _, k in ipairs(Orn.of(slot)) do ks[#ks + 1] = "[" .. q(k.name) .. "," .. q(k.label) .. "," .. Orn.weight(nil, k.name) .. "]" end
  local s = Orn.slots[slot]
  slots[#slots + 1] = "{\\"slot\\":" .. q(slot) .. ",\\"label\\":" .. q(s.label) .. ",\\"desc\\":" .. q(s.desc)
    .. ",\\"kinds\\":[" .. table.concat(ks, ",") .. "]}"
end
return "{\\"kinds\\":[" .. table.concat(kinds, ",") .. "],\\"ornaments\\":[" .. table.concat(slots, ",") .. "],\\"parts\\":[" .. table.concat(parts, ",")
  .. "],\\"groups\\":[" .. table.concat(groups, ",") .. "],\\"inks\\":[" .. table.concat(inks, ",")
  .. "],\\"ramps\\":{" .. table.concat(ramps, ",") .. "},\\"groupInks\\":{" .. table.concat(members, ",")
  .. "},\\"colourways\\":{" .. table.concat(ways, ",") .. "},\\"catalog\\":" .. require("flora.catalog").json(require("flora.catalog").build()) .. "}"
`;

// The transferable objects of the last picture() call.
let transfers = [];

// Lua's output as a message body: a scene drawn to a bitmap `px` wide by
// renderer `mode` (draw.js), or PDF bytes. `view` {y, height} (bp from the
// page's foot) keeps only that band of the page.
// `listed`, when given, is called once the drawing's display list is read.
function picture(out, px, view, mode, listed) {
  if (px) {
    const { bitmap, renderer, ms, listMs } = draw(JSON.parse(out), px, view, mode, listed);
    transfers = [bitmap];
    return { bitmap, renderer, drawMs: Math.round(ms), listMs: Math.round(listMs) };
  }
  const bytes = new TextEncoder().encode(out);
  transfers = [bytes.buffer];
  return { pdf: bytes };
}

// A short hash of every Lua source, which changes whenever the generator
// does.
let version;
async function sourceVersion() {
  version ||= (async () => {
    const all = Object.keys(sources).sort().map((k) => k + "\n" + sources[k]).join("\n");
    const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(all)));
    return Array.from(d.slice(0, 8), (b) => b.toString(16).padStart(2, "0")).join("");
  })();
  return version;
}

onmessage = async (e) => {
  const { id, kind } = e.data;
  try {
    if (kind === "version") {
      postMessage({ id, version: await sourceVersion() });
      return;
    }
    const l = await lua();
    if (kind === "meta") {
      postMessage({ id, meta: JSON.parse(await l.doString(META)) });
      return;
    }
    if (kind === "garden") {
      const { garden, px, png, draw: mode, scene } = e.data;
      if (!(px > 0)) throw new Error("garden: px must be positive");
      const t0 = performance.now();
      const out = await l.doString(`
        local Garden = require("flora.garden")
        local Paint = require("flora.paint")
        local Compose = require("flora.compose")
        local Pdf = require("flora.pdfout")
        local spec, view = Garden.spec(${table(garden)})
        spec.gilt_dpi = math.max(50, math.min(600, ${Number(px)} / spec.width * 72.27))
        Paint.reset_resources()
        local BP = 72 / 72.27
        GARDEN_VIEW = string.format('{"y":%.4f,"height":%.4f}', view.y * BP, view.height * BP)
        return Pdf.scene(Compose.page(spec), spec.width, spec.height)`);
      const view = JSON.parse(await l.doString("return GARDEN_VIEW"));
      if (scene) {
        postMessage({ id, scene: out, view, ms: Math.round(performance.now() - t0) });
        return;
      }
      const msg = picture(out, px, view, mode);
      if (png) {
        // The PNG comes from the bitmap itself, so the cache holds exactly
        // what was shown.
        const c = new OffscreenCanvas(msg.bitmap.width, msg.bitmap.height);
        c.getContext("bitmaprenderer").transferFromImageBitmap(msg.bitmap);
        msg.png = await c.convertToBlob({ type: "image/png" });
        msg.bitmap = await createImageBitmap(msg.png);
        transfers = [msg.bitmap];
      }
      postMessage({ id, ...msg, ms: Math.round(performance.now() - t0) }, transfers);
      return;
    }
    if (kind === "gallery") {
      const { palette, spin, base, px, slot, gilt, giltenv, giltlook, draw: mode } = e.data;
      l.global.set("GILTLOOK", giltlook ?? "");
      const pdf = await l.doString(`
        local Gallery = require("flora.gallery")
        local Mix = require("flora.mix")
        local Paint = require("flora.paint")
        local Pdf = require("flora.pdfout")
        Paint.reset_resources()
        local pal = Mix.resolve(${table(palette)}, 1, ${Number(spin) | 0})
        local Orn = require("flora.ornaments")
        local only = ${slot ? `{ [${JSON.stringify(slot)}] = true }` : "nil"}
        local _, gw = Gallery.layout(3, 560, only)
        local canvas = Paint.new({ backend = "pdf", gilt = ${JSON.stringify(gilt ?? "raster")} })
        canvas.gilt_env = ${JSON.stringify(giltenv ?? "studio")}
        canvas.gilt_look = require("flora.settings").parse("giltlook={" .. GILTLOOK .. "}").giltlook
        -- Gallery gold at most 144 dpi: a sheet of forty-odd kinds at a
        -- retina screen's full resolution takes about ten seconds.
        canvas.gilt_dpi = ${px ? `math.max(50, math.min(144, ${Number(px)} / gw * 72.27))` : 144}
        local pt, cells, w, h = Mix.with_palette(pal, function() return Gallery.sheet(canvas, 3, 560, ${Number(base) | 0}, only) end)
        local rows = {}
        for _, c in ipairs(cells) do
          if c.seed == 1 then
            rows[#rows + 1] = string.format('{"name":"%s","label":"%s","slot":"%s","x":%.1f,"y":%.1f}',
              c.name, c.label, c.slot, c.box[1], h - c.box[4] - c.lift)
          end
        end
        local slots = {}
        for _, name in ipairs(Orn.slot_order) do
          local sl = Orn.slots[name]
          -- The notes for kind authors (o.cord, o.flip) are not for readers.
          local desc = sl.desc:gsub(";[^;]*o%.%a+[^.]*", ""):gsub(" %([^)]*o%.%a+[^)]*%)", "")
          slots[#slots + 1] = string.format('{"name":"%s","label":"%s","desc":"%s"}', name, sl.label, desc)
        end
        GALLERY = string.format('{"w":%.1f,"h":%.1f,"cells":[%s],"slots":[%s]}', w, h, table.concat(rows, ","), table.concat(slots, ","))
        return ${px ? "Pdf.scene" : "Pdf.encode"}(pt, w, h)`);
      const { w, h, cells, slots } = JSON.parse(await l.doString("return GALLERY"));
      postMessage({ id, ...picture(pdf, px, null, mode), cells, slots, w, h }, transfers);
      return;
    }
    const { spec, layout, seed, page, mix, ornaments, palette, spin, px, gilt, giltenv, giltlook, backdrop, draw: mode } = e.data;
    const t0 = performance.now();
    // The page's own progress (compose.lua's spec.progress) is the grow's
    // share of the whole; the PDF scene and the drawing follow.
    l.global.set("PROGRESS", (f) => postMessage({ id, progress: f * PROGRESS.grow }));
    l.global.set("SPEC", spec);
    l.global.set("GILTLOOK", giltlook ?? "");
    l.global.set("SEED", String(seed));
    l.global.set("BACKDROP", backdrop ?? "light");
    // `layout`, when given, replaces the baked page's own (frames.lua).
    l.global.set("LAYOUT", layout ?? "");
    await l.doString(`
      local Serial = require("flora.serial")
      local Paint = require("flora.paint")
      local Compose = require("flora.compose")
      local Pdf = require("flora.pdfout")
      local Init = require("flora.init")
      local spec = Serial.decode(SPEC)
      spec.seed = Init.seed(SEED, ${Number(page) | 0})
      if LAYOUT ~= "" then spec.layout = LAYOUT end
      spec.mix = ${table(mix)}
      spec.ornaments = ${table(ornaments)}
      spec.palette = ${table(palette)}
      spec.spin = ${Number(spin) | 0}
      spec.gilt = ${JSON.stringify(gilt ?? "raster")}
      spec.gilt_env = ${JSON.stringify(giltenv ?? "studio")}
      spec.gilt_look = require("flora.settings").parse("giltlook={" .. GILTLOOK .. "}").giltlook
      spec.backdrop = require("flora.settings").parse("backdrop=" .. BACKDROP).backdrop
      spec.gilt_dpi = ${px ? `math.max(50, math.min(600, ${Number(px)} / spec.width * 72.27))` : 150}
      spec.progress = PROGRESS
      Paint.reset_resources()
      PAGE, PAGE_W, PAGE_H = Compose.page(spec), spec.width, spec.height`);
    const tGrown = performance.now();
    const pdf = await l.doString(`
      local Pdf = require("flora.pdfout")
      local out = ${px ? "Pdf.scene" : "Pdf.encode"}(PAGE, PAGE_W, PAGE_H)
      PAGE = nil
      return out`);
    const tScene = performance.now();
    postMessage({ id, progress: PROGRESS.scene });
    const out = picture(pdf, px, null, mode, () => postMessage({ id, progress: PROGRESS.listed }));
    out.timing = { grow: tGrown - t0, scene: tScene - tGrown, draw: performance.now() - tScene, list: out.listMs ?? 0 };
    postMessage({ id, ...out, ms: Math.round(performance.now() - t0) }, transfers);
  } catch (err) {
    postMessage({ id, error: String(err && err.message || err) });
  }
};
