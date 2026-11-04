// The renderer bench (site/tools/renderers.html) in headless Chrome with
// the machine's GPU: prints its table and exits non-zero when it fails, or
// when the two renderers differ at more than 3% of inked samples.
//
//   node site/tests/renderers-bench.mjs [key=value ...]
//     keys as the page's form: mode, width, height, x0, x1, dpr, grow,
//     seed, settings, runs; e.g. dpr=1 settings=backdrop=dark
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SITE = join(dirname(fileURLToPath(import.meta.url)), "..");
const PORT = process.env.BENCH_PORT || "4318";
const query = new URLSearchParams();
for (const arg of process.argv.slice(2)) {
  const i = arg.indexOf("=");
  if (i < 1) throw new Error(`expected key=value, got ${arg}`);
  query.set(arg.slice(0, i), arg.slice(i + 1));
}
const url = `http://127.0.0.1:${PORT}/tools/renderers.html?${query}`;

const server = spawn("npx", ["vite", "--port", PORT, "--strictPort", "--host", "127.0.0.1"], { cwd: SITE, stdio: ["ignore", "ignore", "inherit"] });
let browser, failed = false;
try {
  let up = false;
  for (let i = 0; i < 100 && !up; i++) {
    try { up = (await fetch(url)).ok; } catch { await new Promise((r) => setTimeout(r, 150)); }
  }
  if (!up) throw new Error(`the dev server did not answer at ${url}`);
  browser = await chromium.launch({ channel: "chrome", headless: true, args: ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"] });
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  await page.goto(url);
  await page.waitForFunction(() => window.bench, null, { timeout: 300000 });
  const r = await page.evaluate(() => window.bench);
  if (r.error || errors.length) throw new Error(r.error ?? errors.join("; "));
  const rows = await page.$$eval("#results tr", (trs) => trs.map((tr) => [tr.cells[0]?.textContent ?? tr.querySelector("th").textContent, tr.querySelector("td").textContent]));
  const w = Math.max(...rows.map(([k]) => k.length));
  for (const [k, v] of rows) console.log(`${k.padEnd(w)}  ${v}`);
  if (r.differ > r.inked * 0.03) {
    console.error(`FAIL: the renderers differ at ${r.differ} of ${r.inked} inked samples`);
    failed = true;
  }
} catch (e) {
  console.error("FAIL: " + e.message);
  failed = true;
} finally {
  await browser?.close();
  server.kill();
}
process.exit(failed ? 1 : 0);
