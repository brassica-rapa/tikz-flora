// The main thread's side of the render worker, and drawing its PDF.
import * as pdfjs from "pdfjs-dist";
import pdfWorker from "pdfjs-dist/build/pdf.worker.min.mjs?url";

pdfjs.GlobalWorkerOptions.workerSrc = pdfWorker;

let worker, next = 0;
const waiting = new Map();

// Send `msg` to the worker; its reply settles the promise, and messages
// carrying only `progress` along the way go to `onProgress`.
function post(msg, onProgress) {
  worker ||= (() => {
    const w = new Worker(new URL("./render.worker.js", import.meta.url), { type: "module" });
    w.onmessage = (e) => {
      const p = waiting.get(e.data.id);
      if (!p) return;
      if ("progress" in e.data) {
        p.onProgress?.(e.data.progress);
        return;
      }
      waiting.delete(e.data.id);
      if (e.data.error) p.reject(new Error(e.data.error));
      else p.resolve(e.data);
    };
    return w;
  })();
  const id = ++next;
  return new Promise((resolve, reject) => {
    waiting.set(id, { resolve, reject, onProgress });
    worker.postMessage({ ...msg, id });
  });
}

export async function meta() {
  return (await post({ kind: "meta" })).meta;
}

// Ornament gold: computed per pixel by default (lua/flora/orn_raster.lua),
// the vector relief with ?gilt=vector; ?giltenv=mirror makes raster gold
// reflect the vector relief's surroundings, and ?giltlook=horizon=0.1,
// grain=0 changes keys of the look as \florasetup{giltlook={...}} does.
const query = new URLSearchParams(globalThis.location?.search ?? "");
const gilt = query.get("gilt") === "vector" ? "vector" : "raster";
const giltenv = query.get("giltenv") === "mirror" ? "mirror" : "studio";
const giltlook = query.get("giltlook") ?? "";

// The renderer: "webgl" (default) draws the content stream in the worker
// with flora's WebGL2 renderer (draw.js), falling back to its 2D canvas
// renderer where WebGL2 is missing; "canvas2d" asks for the 2D canvas, and
// "pdf" draws a PDF with pdf.js, for comparison (?renderer=canvas2d|pdf).
export const renderer = ({ pdf: "pdf", canvas2d: "canvas2d" })[query.get("renderer")] ?? "webgl";

// Render `job`; `onProgress(f)`, when given, is told how far it has got
// (0 to 1, rising) as the worker grows and draws the page.
export async function render(job, onProgress) {
  return post({ kind: "render", gilt, giltenv, giltlook, draw: renderer, ...job }, onProgress);
}

export async function gallery(job) {
  return post({ kind: "gallery", gilt, giltenv, giltlook, draw: renderer, ...job });
}

// The picture's width in device pixels for `width` CSS pixels, when the
// worker draws it; undefined when pdf.js does.
export function px(width) {
  return renderer === "pdf" ? undefined : Math.round(width * (window.devicePixelRatio || 1));
}

// The renderer that drew a worker's output `out`, for status lines.
export function drawnBy(out) {
  return out.renderer === "webgl" ? "WebGL" : out.renderer === "canvas2d" ? "2D canvas" : "pdf.js";
}

// Show a worker's output on `canvas` at `width` CSS pixels: its bitmap, or
// its PDF drawn by pdf.js.
export async function show(out, canvas, width) {
  if (!out.bitmap) return draw(out.pdf, canvas, width);
  canvas.width = out.bitmap.width;
  canvas.height = out.bitmap.height;
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(out.bitmap, 0, 0);
  out.bitmap.close();
}

// Draw PDF bytes on `canvas` at `width` CSS pixels.
export async function draw(bytes, canvas, width) {
  const task = pdfjs.getDocument({ data: bytes });
  const doc = await task.promise;
  try {
    const page = await doc.getPage(1);
    const base = page.getViewport({ scale: 1 });
    const ratio = window.devicePixelRatio || 1;
    const vp = page.getViewport({ scale: (width / base.width) * ratio });
    canvas.width = Math.round(vp.width);
    canvas.height = Math.round(vp.height);
    await page.render({ canvas, viewport: vp }).promise;
  } finally {
    await task.destroy();
  }
}
