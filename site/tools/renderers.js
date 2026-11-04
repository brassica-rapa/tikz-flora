// The renderer bench (just renderers): grows one garden in the generator's
// worker, then draws its scene on this page with flora's WebGL2 and 2D
// canvas renderers, timing each over several runs and marking where their
// pictures differ. The form's values are kept in the URL, so a link
// reproduces a run. When done, window.bench holds the last result for
// tests/renderers-bench.mjs.
import { fromPdfScene, WebGLRenderer, drawCanvas2D, stats } from "@alpaca-software/web-flora";

const form = document.getElementById("opts");
const statusEl = document.getElementById("status");
const table = document.getElementById("results");
const glCanvas = document.getElementById("webgl");
const c2dCanvas = document.getElementById("c2d");
const diffCanvas = document.getElementById("diff");

const FIELDS = ["mode", "width", "height", "x0", "x1", "dpr", "grow", "seed", "settings", "runs"];
const query = new URLSearchParams(location.search);
for (const k of FIELDS) if (query.has(k)) form.elements[k].value = query.get(k);

let worker, next = 0;
const waiting = new Map();
function post(msg) {
  worker ||= (() => {
    const w = new Worker(new URL("../src/lib/render.worker.js", import.meta.url), { type: "module" });
    w.onmessage = (e) => {
      const p = waiting.get(e.data.id);
      waiting.delete(e.data.id);
      if (e.data.error) p?.reject(new Error(e.data.error));
      else p?.resolve(e.data);
    };
    return w;
  })();
  const id = ++next;
  return new Promise((resolve, reject) => {
    waiting.set(id, { resolve, reject });
    worker.postMessage({ ...msg, id });
  });
}

function say(text, bad = false) {
  statusEl.textContent = text;
  statusEl.className = bad ? "bad" : "";
}

function values() {
  const v = Object.fromEntries(FIELDS.map((k) => [k, form.elements[k].value]));
  for (const k of ["width", "height", "x0", "x1", "dpr", "grow", "seed", "runs"]) {
    v[k] = Number(v[k]);
    if (!Number.isFinite(v[k])) throw new Error(`${k} is not a number`);
  }
  if (v.mode === "margins" && !(v.x0 < v.x1 && v.x1 <= v.width)) throw new Error("the column needs x0 < x1 <= width");
  if (!(v.grow >= 0 && v.grow <= 1)) throw new Error("grow must be 0 to 1");
  v.runs = Math.max(1, Math.min(50, Math.round(v.runs)));
  return v;
}

const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};

// The grown scene and the picture's geometry, kept for Redraw.
let grown = null;
let gl = null;

async function grow() {
  const v = values();
  history.replaceState(null, "", "?" + new URLSearchParams(Object.fromEntries(FIELDS.map((k) => [k, String(form.elements[k].value)]))));
  const garden = { mode: v.mode, width: Math.round(v.width), height: Math.round(v.height), seed: Math.round(v.seed), grow: v.grow, settings: v.settings };
  if (v.mode === "margins") Object.assign(garden, { x0: Math.round(v.x0), x1: Math.round(v.x1) });
  const px = Math.round(garden.width * v.dpr);
  // Dark-backdrop flora is light ink over nothing: show it on a dark page.
  document.body.style.background = /backdrop\s*=\s*dark/.test(v.settings) ? "#11181c" : "";
  document.body.style.color = /backdrop\s*=\s*dark/.test(v.settings) ? "#e8e2d6" : "";
  say("Growing in the worker (Lua under wasmoon)…");
  const out = await post({ kind: "garden", garden, px, scene: true });
  const t0 = performance.now();
  const scene = JSON.parse(out.scene);
  const t1 = performance.now();
  const list = fromPdfScene(scene);
  const t2 = performance.now();
  const scale = px / scene.width;
  grown = {
    v, list, scale, compute: out.ms, parse: t1 - t0, read: t2 - t1, bytes: out.scene.length,
    y0: scene.height - out.view.y - out.view.height,
    w: px, h: Math.round(out.view.height * scale),
  };
  await redraw();
}

async function redraw() {
  if (!grown) return grow();
  const { list, scale, y0, w, h } = grown;
  const runs = values().runs;
  for (const c of [glCanvas, c2dCanvas, diffCanvas]) {
    c.width = w;
    c.height = h;
    c.style.width = `${w / grown.v.dpr}px`;
  }
  say(`Drawing ${runs} times with each renderer…`);
  await new Promise(requestAnimationFrame);

  gl ??= new WebGLRenderer(glCanvas);
  const glRuns = [];
  for (let i = 0; i < runs; i++) {
    const t = performance.now();
    const r = gl.draw(list, { scale, y0 });
    glRuns.push({ total: performance.now() - t, prepare: r.prepare, draw: r.draw, triangles: r.triangles });
  }

  const ctx = c2dCanvas.getContext("2d", { willReadFrequently: false });
  const c2dRuns = [];
  for (let i = 0; i < runs; i++) {
    const t = performance.now();
    drawCanvas2D(ctx, list, { scale, y0 });
    ctx.getImageData(0, 0, 1, 1); // waits for the canvas to finish drawing
    c2dRuns.push(performance.now() - t);
  }

  const diff = compare();
  const s = stats(list);
  const result = {
    size: `${w} × ${h} device px`,
    computeMs: grown.compute, sceneKB: Math.round(grown.bytes / 1024), parseMs: grown.parse, readMs: grown.read,
    fills: s.fills, strokes: s.strokes, images: s.images, clips: s.clips, commands: s.commands,
    webgl: { totalMs: median(glRuns.map((r) => r.total)), prepareMs: median(glRuns.map((r) => r.prepare)), drawMs: median(glRuns.map((r) => r.draw)), triangles: glRuns[0].triangles },
    canvas2dMs: median(c2dRuns), runs,
    differ: diff.differ, inked: diff.inked,
  };
  result.speedup = result.canvas2dMs / result.webgl.totalMs;
  show(result);
  window.bench = result;
  say(`Done: WebGL ${result.speedup.toFixed(1)}× the 2D canvas's speed.`);
}

// Marks on the diff canvas each 3 × 3 sample where the two pictures,
// composited over the page's colour, differ by more than 48 in a channel.
function compare() {
  const { w, h } = grown;
  const read = (src) => {
    const c = new OffscreenCanvas(w, h);
    const x = c.getContext("2d");
    x.drawImage(src, 0, 0);
    return x.getImageData(0, 0, w, h).data;
  };
  const a = read(glCanvas), b = read(c2dCanvas);
  const bg = getComputedStyle(document.body).backgroundColor.match(/\d+/g).map(Number);
  const dctx = diffCanvas.getContext("2d");
  dctx.clearRect(0, 0, w, h);
  dctx.globalAlpha = 0.35;
  dctx.drawImage(c2dCanvas, 0, 0);
  dctx.globalAlpha = 1;
  dctx.fillStyle = "#e0201a";
  let differ = 0, inked = 0;
  for (let y = 0; y + 3 <= h; y += 3) {
    for (let x = 0; x + 3 <= w; x += 3) {
      const sa = [0, 0, 0], sb = [0, 0, 0];
      let alpha = 0;
      for (let v = 0; v < 3; v++) {
        for (let u = 0; u < 3; u++) {
          const i = ((y + v) * w + x + u) * 4, aa = a[i + 3] / 255, ab = b[i + 3] / 255;
          alpha = Math.max(alpha, a[i + 3], b[i + 3]);
          for (let k = 0; k < 3; k++) {
            sa[k] += a[i + k] + bg[k] * (1 - aa); // premultiplied over the page
            sb[k] += b[i + k] + bg[k] * (1 - ab);
          }
        }
      }
      if (alpha < 8) continue;
      inked++;
      if (Math.max(...sa.map((s, k) => Math.abs(s - sb[k]) / 9)) > 48) {
        differ++;
        dctx.fillRect(x, y, 3, 3);
      }
    }
  }
  return { differ, inked };
}

function show(r) {
  const ms = (x) => `${x.toFixed(1)} ms`;
  const rows = [
    ["Picture", r.size],
    ["Grow (worker, Lua)", ms(r.computeMs)],
    ["Scene", `${r.sceneKB} KB; JSON.parse ${ms(r.parseMs)}, flora's reader ${ms(r.readMs)}`],
    ["Display list", `${r.fills} fills, ${r.strokes} strokes, ${r.images} images, ${r.clips} clips, ${r.commands} path commands`],
    [`WebGL2 (median of ${r.runs})`, `${ms(r.webgl.totalMs)}: prepare ${ms(r.webgl.prepareMs)}, draw ${ms(r.webgl.drawMs)}, ${r.webgl.triangles.toLocaleString()} triangles`],
    [`2D canvas (median of ${r.runs})`, ms(r.canvas2dMs)],
    ["Speed-up", `${r.speedup.toFixed(1)}×`],
    ["Difference", `${r.differ} of ${r.inked} inked samples (${((r.differ / Math.max(1, r.inked)) * 100).toFixed(2)}%)`],
  ];
  table.replaceChildren(...rows.map(([k, val]) => {
    const tr = document.createElement("tr");
    const th = document.createElement("th");
    const td = document.createElement("td");
    th.textContent = k;
    td.textContent = val;
    tr.append(th, td);
    return tr;
  }));
}

const run = (f) => f().catch((e) => { say(`Failed: ${e.message}`, true); window.bench = { error: e.message }; });
form.addEventListener("submit", (e) => { e.preventDefault(); run(grow); });
form.elements.redraw.addEventListener("click", () => run(redraw));
run(grow);
