// The garden bundle (build/garden, `just garden`) in headless Chrome, served
// from a folder of its own as another site would serve it: it grows both
// margins round a bare column and a band, reads the cache on a second
// visit, and fails loudly on a bad garden.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const ROOT = join(fileURLToPath(new URL(".", import.meta.url)), "../../build/garden");
const TYPES = { ".js": "text/javascript", ".html": "text/html", ".wasm": "application/wasm" };
const PAGE = `<!doctype html><meta charset="utf-8"><title>garden</title>
<script type="module">
  import { createGarden } from "/vendor/garden/garden.js";
  window.garden = createGarden();
  // The bitmap's inked share in the left margin, the column and the right.
  window.measure = (b, x0, x1) => {
    const c = new OffscreenCanvas(b.width, b.height), g = c.getContext("2d");
    g.drawImage(b, 0, 0);
    const d = g.getImageData(0, 0, b.width, b.height).data, k = b.width / ${"window.cssWidth"};
    const n = [0, 0, 0], all = [0, 0, 0];
    for (let y = 0; y < b.height; y += 3) for (let x = 0; x < b.width; x += 3) {
      const zone = x < x0 * k ? 0 : x < x1 * k ? 1 : 2;
      all[zone]++;
      if (d[(y * b.width + x) * 4 + 3] > 40) n[zone]++;
    }
    return n.map((v, i) => v / all[i]);
  };
  window.ready = true;
</script>`;

let failures = 0;
const check = (ok, msg) => { if (!ok) { failures++; console.error("FAIL: " + msg); } };

const server = createServer(async (req, res) => {
  const path = new URL(req.url, "http://x").pathname;
  if (path === "/") return res.writeHead(200, { "content-type": "text/html" }).end(PAGE);
  if (!path.startsWith("/vendor/garden/")) return res.writeHead(404).end();
  const file = normalize(join(ROOT, path.slice("/vendor/garden/".length)));
  if (!file.startsWith(ROOT)) return res.writeHead(403).end();
  try {
    res.writeHead(200, { "content-type": TYPES[extname(file)] ?? "application/octet-stream" }).end(await readFile(file));
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const URL_ = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({ channel: "chrome", headless: true, args: ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"] });
try {
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  const outside = [];
  page.on("request", (r) => { if (!r.url().startsWith(URL_) && !r.url().startsWith("data:") && !r.url().startsWith("blob:")) outside.push(r.url()); });
  await page.goto(URL_);
  await page.waitForFunction(() => window.ready);

  // Margins at a small viewport, on a dark backdrop, at full growth.
  const W = 900, H = 560, X0 = 150, X1 = 750;
  const date = "2026-07-02T16:00:00Z";
  const first = await page.evaluate(async ({ W, H, X0, X1, date }) => {
    window.cssWidth = W;
    const t0 = performance.now();
    const r = await garden.grow({ mode: "margins", width: W, height: H, x0: X0, x1: X1, dpr: 1, settings: "backdrop=dark", date: new Date(date), timeZone: "UTC" });
    return { w: r.bitmap.width, h: r.bitmap.height, cached: r.cached, at: r.at, ms: performance.now() - t0, ink: measure(r.bitmap, X0, X1) };
  }, { W, H, X0, X1, date });
  console.log(`margins ${W}x${H}: ${(first.ms / 1000).toFixed(1)} s, ink ${first.ink.map((v) => v.toFixed(2)).join(" / ")}`);
  check(first.w === W && first.h === H, `margins bitmap is ${first.w}x${first.h}`);
  check(!first.cached, "the first garden came from the cache");
  check(first.at.colourway === "summer" && first.at.grow === 1, `July 16:00 UTC is ${JSON.stringify(first.at)}`);
  check(first.ink[0] > 0.08 && first.ink[2] > 0.08, "a margin is bare");
  check(first.ink[1] < 0.02, `the column is ${(first.ink[1] * 100).toFixed(1)}% inked`);

  // The same garden again comes from the cache, the same picture.
  const again = await page.evaluate(async ({ W, H, X0, X1, date }) => {
    const t0 = performance.now();
    const r = await garden.grow({ mode: "margins", width: W, height: H, x0: X0, x1: X1, dpr: 1, settings: "backdrop=dark", date: new Date(date), timeZone: "UTC" });
    return { cached: r.cached, ms: performance.now() - t0, ink: measure(r.bitmap, X0, X1) };
  }, { W, H, X0, X1, date });
  console.log(`margins again: ${again.ms.toFixed(0)} ms, cached ${again.cached}`);
  check(again.cached, "the second garden was grown again");
  check(again.ink.every((v, i) => Math.abs(v - first.ink[i]) < 0.005), "the cached garden differs from the grown one");

  // A band, before dawn: a seedling, much less ink than the full margins.
  const band = await page.evaluate(async () => {
    window.cssWidth = 390;
    const r = await garden.grow({ mode: "band", width: 390, height: 110, dpr: 2, settings: "backdrop=dark", date: new Date("2026-07-02T03:00:00Z"), timeZone: "UTC", cache: false });
    return { w: r.bitmap.width, h: r.bitmap.height, at: r.at, ink: measure(r.bitmap, 0, 0) };
  });
  check(band.w === 780 && band.h === 220, `band bitmap is ${band.w}x${band.h}`);
  check(band.at.grow < 0.1, `03:00 grows ${band.at.grow}`);
  check(band.ink[2] > 0 && band.ink[2] < first.ink[0], `the night band is ${band.ink[2]} inked`);
  const day = await page.evaluate(async () => {
    const r = await garden.grow({ mode: "band", width: 390, height: 110, dpr: 2, settings: "backdrop=dark", date: new Date("2026-07-02T18:00:00Z"), timeZone: "UTC", cache: false });
    return measure(r.bitmap, 0, 0);
  });
  check(day[2] > band.ink[2] * 3, `the full band (${day[2]}) is not much fuller than the night one (${band.ink[2]})`);

  // A bad garden rejects with the generator's message.
  const bad = await page.evaluate(() => garden.grow({ mode: "margins", width: 300, height: 300, x0: 20, x1: 280, cache: false }).then(() => "grew", (e) => e.message));
  check(/margins under/.test(bad), `a too-narrow margin gave: ${bad}`);

  check(outside.length === 0, `the garden fetched from elsewhere: ${outside.join(", ")}`);
  check(errors.length === 0, "page errors: " + errors.join("; "));
} finally {
  await browser.close();
  server.close();
}
if (failures) {
  console.error(`garden: ${failures} failure(s)`);
  process.exit(1);
}
console.log("garden bundle: ok");
