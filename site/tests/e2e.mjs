// End-to-end check of the built site in headless Chrome: every page is
// served with its own link preview and links only to pages and assets that
// exist; the mixer starts the Lua generator, grows a page onto the canvas,
// grows it again when a weight changes and offers a \florasetup line that
// matches the controls; a colourway on the home page opens in the mixer;
// the ornaments page draws every kind.
//
//   just test-site      (bakes and builds first; needs Google Chrome)
//   SITE_URL=https://flora.alpacasoft.dev/ node site/tests/e2e.mjs
//                       (checks a deployed site instead of a local preview)
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SITE = join(dirname(fileURLToPath(import.meta.url)), "..");
const PORT = process.env.SITE_TEST_PORT || "4317";
const URL = process.env.SITE_URL || `http://127.0.0.1:${PORT}/`;
const PAGES = { home: "", mixer: "mixer/", ornaments: "ornaments/", guide: "guide/" };
const MIXER = URL + PAGES.mixer;
const ORNAMENTS = URL + PAGES.ornaments;

let failures = 0;
function check(cond, msg) {
  if (!cond) {
    failures++;
    console.error("FAIL: " + msg);
  }
}

// tests/test_scene_ops.lua holds every page's operators to scene-ops.json;
// flora's scene reader must know exactly that list.
{
  const ops = JSON.parse(readFileSync(join(SITE, "src/lib/scene-ops.json"), "utf8"));
  const { OPERATORS } = await import("@alpaca-software/web-flora");
  check(Array.isArray(OPERATORS), "flora's scene reader no longer exports OPERATORS");
  if (OPERATORS) check(JSON.stringify(OPERATORS) === JSON.stringify(ops), `flora reads ${JSON.stringify(OPERATORS)}; scene-ops.json lists ${JSON.stringify(ops)}`);
}

const server = process.env.SITE_URL ? null : spawn("npx", ["vite", "preview", "--port", PORT, "--strictPort", "--host", "127.0.0.1"], {
  cwd: SITE, stdio: ["ignore", "ignore", "pipe"],
});
let browser;
try {
  for (let i = 0; i < 100; i++) {
    try { if ((await fetch(URL)).ok) break; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 150));
  }
  for (const path of ["tikzflora.zip", "media/grow.mp4", "media/grow.gif", "img/og.jpg", "img/page-1.jpg", "bake/manifest.json",
    "img/colourway-0.jpg", "img/colourway-1.jpg", "img/colourway-2.jpg", "img/flora-margin.png",
    "img/title-1.jpg", "img/title-4.jpg", "bake/catalog.json",
    ...["outline", "shaded", "engraved"].flatMap((st) => [0, 20, 40].flatMap((a) =>
      [11, 14].flatMap((p) => [`bake/spec-${p}-${st}-${a}.lua`, `bake/text-${p}-${st}-${a}.png`, `bake/letters-${p}-${st}-${a}.png`])))]) {
    const r = await fetch(URL + path);
    check(r.ok, `${path} is not served (${r.status})`);
  }
  // The GPU flags give headless Chrome hardware WebGL2, as browsers have.
  browser = await chromium.launch({ channel: "chrome", headless: true, args: ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"] });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, permissions: ["clipboard-read", "clipboard-write"] });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));

  // Each page has its own title and link preview, marks itself in the nav,
  // and links only to things that are served.
  const titles = new Set();
  const links = new Set();
  for (const [name, path] of Object.entries(PAGES)) {
    await page.goto(URL + path);
    const og = (k) => page.locator(`meta[property="og:${k}"]`).getAttribute("content");
    check(await og("image") === "https://flora.alpacasoft.dev/img/og.jpg", `${name}: og:image is not the absolute preview URL`);
    check(await og("url") === `https://flora.alpacasoft.dev/${path}`, `${name}: og:url is ${await og("url")}`);
    check(await page.locator('link[rel="canonical"]').getAttribute("href") === await og("url"), `${name}: canonical differs from og:url`);
    check(!!(await og("description")), `${name}: no og:description`);
    titles.add(await page.title());
    const current = await page.locator('[aria-current="page"]').first().getAttribute("href");
    check(current === `/${path}`, `${name}: the nav marks ${current} as current`);
    for (const href of await page.locator("a[href^='/']").evaluateAll((as) => as.map((a) => a.getAttribute("href")))) links.add(href.split("#")[0]);
  }
  check(titles.size === Object.keys(PAGES).length, `pages share titles: ${[...titles].join(" | ")}`);
  for (const href of links) {
    const r = await fetch(new globalThis.URL(href, URL));
    check(r.ok, `the link ${href} is not served (${r.status})`);
  }
  // Every value the mixer's progress bar takes, as it takes it.
  await page.addInitScript(() => {
    window.__bar = [];
    new MutationObserver((ms) => {
      for (const m of ms) if (m.target.classList?.contains("bar")) window.__bar.push([m.target.getAttribute("aria-valuenow"), m.target.classList.contains("on")]);
    }).observe(document, { subtree: true, attributes: true, attributeFilter: ["aria-valuenow", "class"] });
  });
  await page.goto(MIXER);
  const code = () => page.locator(".controls pre code").textContent();
  const grown = async () => {
    await page.locator(".status", { hasText: "Growing" }).waitFor({ timeout: 10000 });
    await page.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
  };
  // Inked samples of the canvas, and how many of them are blue.
  const inked = () => page.evaluate(() => {
    const c = document.querySelector(".sheet canvas");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let n = 0, blue = 0;
    for (let i = 0; i < d.length; i += 4 * 7) {
      if (d[i + 3] > 0 && d[i] + d[i + 1] + d[i + 2] < 600) {
        n++;
        if (d[i + 2] > d[i] + 40 && d[i + 2] > d[i + 1] + 15) blue++;
      }
    }
    return { n, blue: blue / Math.max(1, n) };
  });

  // The mixer starts on the first colourway: a full page with little blue.
  await page.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
  const first = await inked();
  check(first.n > 2000, `the first page shows too little flora (${first.n} inked samples)`);
  check(first.blue < 0.1, `the first colourway is ${(first.blue * 100).toFixed(0)}% blue`);
  check(/seed=11,/.test(await code()) && /colourway=ember\}$/.test(await code()), `the mixer does not start on the first colourway: ${await code()}`);

  // The progress bar follows the grow: many steps between 0 and 100, never
  // falling, then put away once the page is grown.
  await page.waitForFunction(() => !document.querySelector(".bar").classList.contains("on"), null, { timeout: 5000 }).catch(() => {});
  const bar = (await page.evaluate(() => window.__bar)).filter(([v]) => v !== null).map(([v]) => Number(v));
  const between = new Set(bar.filter((v) => v > 0 && v < 100));
  check(between.size >= 10, `the progress bar moved through only ${between.size} values: ${bar.join(" ")}`);
  check(bar.every((v, i) => i === 0 || v >= bar[i - 1] || v === 0), `the progress bar fell during a grow: ${bar.join(" ")}`);
  check(bar.at(-1) === 100, `the progress bar ends at ${bar.at(-1)}`);
  check(!(await page.locator(".bar").evaluate((b) => b.classList.contains("on"))), "the progress bar stays up after the grow");

  // flora's WebGL renderer (draw.js, the default) draws what pdf.js draws
  // from the same page's PDF, up to antialiasing: few sampled pixels differ
  // visibly. So does flora's 2D canvas renderer (?renderer=canvas2d).
  check(/\(WebGL\)/.test(await page.locator(".status").textContent()), `the mixer did not draw with WebGL: ${await page.locator(".status").textContent()}`);
  const pixels = (p, at = ".sheet canvas") => p.evaluate((at) => {
    const c = document.querySelector(at);
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    // Each sample averages a 3 x 3 block over white paper, so a hairline
    // antialiased half a pixel differently does not count as a difference.
    const out = [];
    for (let y = 0; y + 3 <= c.height; y += 3) {
      for (let x = 0; x + 3 <= c.width; x += 3) {
        const sum = [0, 0, 0];
        for (let v = 0; v < 3; v++) {
          for (let u = 0; u < 3; u++) {
            const i = ((y + v) * c.width + x + u) * 4, a = d[i + 3] / 255;
            for (let k = 0; k < 3; k++) sum[k] += d[i + k] * a + 255 * (1 - a);
          }
        }
        out.push(...sum.map((v) => Math.round(v / 9)));
      }
    }
    return { w: Math.floor(c.width / 3), h: Math.floor(c.height / 3), px: out };
  }, at);
  // Samples that differ visibly between two pictures, of those inked.
  const compare = (a, b) => {
    const w = Math.min(a.w, b.w), h = Math.min(a.h, b.h);
    let differ = 0, ink = 0;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const i = (y * a.w + x) * 3, j = (y * b.w + x) * 3;
        const d = Math.max(Math.abs(a.px[i] - b.px[j]), Math.abs(a.px[i + 1] - b.px[j + 1]), Math.abs(a.px[i + 2] - b.px[j + 2]));
        if (b.px[j] + b.px[j + 1] + b.px[j + 2] < 720) ink++;
        if (d > 48) differ++;
      }
    }
    return { differ, ink };
  };
  {
    const viaPdf = await context.newPage();
    await viaPdf.goto(MIXER + "?renderer=pdf");
    await viaPdf.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
    check(/pdf\.js/.test(await viaPdf.locator(".status").textContent()), "?renderer=pdf did not draw with pdf.js");
    const [a, b] = [await pixels(page), await pixels(viaPdf)];
    await viaPdf.close();
    const { differ, ink } = compare(a, b);
    console.log(`renderers: ${differ} of ${ink} inked samples differ (${((differ / Math.max(1, ink)) * 100).toFixed(2)}%), sizes ${a.w}x${a.h} / ${b.w}x${b.h}`);
    check(Math.abs(a.w - b.w) <= 1 && Math.abs(a.h - b.h) <= 1, `the renderers draw different sizes (${a.w}x${a.h}, ${b.w}x${b.h})`);
    check(ink > 2000 && differ < ink * 0.03, `WebGL and pdf.js differ at ${differ} of ${ink} inked samples`);

    const via2d = await context.newPage();
    await via2d.goto(MIXER + "?renderer=canvas2d");
    await via2d.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
    check(/\(2D canvas\)/.test(await via2d.locator(".status").textContent()), "?renderer=canvas2d did not draw with the 2D canvas");
    const c2 = await pixels(via2d);
    await via2d.close();
    const r2 = compare(c2, b);
    console.log(`2D canvas renderer: ${r2.differ} of ${r2.ink} inked samples differ from pdf.js`);
    check(r2.ink > 2000 && r2.differ < r2.ink * 0.03, `the 2D canvas and pdf.js differ at ${r2.differ} of ${r2.ink} inked samples`);

    // Gold is raster by default (the page above). The vector relief
    // (?gilt=vector) and the mirror look (?giltenv=mirror) also draw with
    // WebGL as pdf.js draws them. This page holds little gold, so the
    // gallery below checks that each one changes it.
    for (const [q, label] of [["?gilt=vector", "vector gilt"], ["?giltenv=mirror", "mirror gilt"]]) {
      const [alt, altPdf] = [await context.newPage(), await context.newPage()];
      await alt.goto(MIXER + q);
      await altPdf.goto(MIXER + q + "&renderer=pdf");
      for (const p of [alt, altPdf]) await p.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 240000 });
      console.log(`${label}: ${await alt.locator(".status").textContent()} / pdf.js: ${await altPdf.locator(".status").textContent()}`);
      const [c, d] = [await pixels(alt), await pixels(altPdf)];
      await alt.close();
      await altPdf.close();
      const r = compare(c, d);
      console.log(`${label} renderers: ${r.differ} of ${r.ink} inked samples differ`);
      check(r.ink > 2000 && r.differ < r.ink * 0.03, `with ${label}, WebGL and pdf.js differ at ${r.differ} of ${r.ink} inked samples`);
    }
  }

  // The mixer fills the screen, and scrolling the controls leaves the page
  // viewer where it is.
  const sheetTop = () => page.evaluate(() => document.querySelector(".sheet").getBoundingClientRect().top);
  check(await page.evaluate(() => document.documentElement.scrollHeight <= innerHeight + 1), "the mixer page scrolls as a whole");
  const top0 = await sheetTop();
  const scrollY0 = await page.evaluate(() => window.scrollY);
  await page.locator(".controls").hover();
  await page.mouse.wheel(0, 600);
  await page.waitForTimeout(300);
  const scrolled = await page.evaluate(() => document.querySelector(".controls").scrollTop);
  check(scrolled > 100, `the controls did not scroll (${scrolled})`);
  check(Math.abs((await sheetTop()) - top0) < 1 && (await page.evaluate(() => window.scrollY)) === scrollY0,
    `scrolling the controls moved the page viewer (top ${top0} -> ${await sheetTop()}, scrollY ${scrollY0} -> ${await page.evaluate(() => window.scrollY)})`);

  // The original look is blue, and spinning has nothing to spin in it.
  await page.getByRole("button", { name: "Original blue" }).click();
  await grown();
  const original = await inked();
  check(original.blue > 0.3, `the original look is only ${(original.blue * 100).toFixed(0)}% blue; the measure is broken`);
  check(await page.getByRole("button", { name: "Spin random inks" }).isDisabled(), "Spin random inks is enabled with no random part");

  // Zero weights (behind their disclosures) grow a sparser page, and the
  // line follows the controls.
  for (const summary of await page.locator(".controls summary").all()) await summary.click();
  const slider = (name) => page.locator(".controls details .row", { has: page.locator("span", { hasText: new RegExp(`^${name}$`) }) })
    .locator('input[type="range"]');
  for (const name of ["Leaves", "Baby's breath", "Forget-me-nots", "Sprays"]) await slider(name).fill("0");
  await grown();
  const second = await inked();
  check(second.n < original.n * 0.85, `zero weights did not thin the page (${original.n} -> ${second.n})`);
  const line = await code();
  check(/leaves=0/.test(line) && /gyps=0/.test(line), `setup line does not follow the controls: ${line}`);
  check(line.startsWith("\\florasetup{layout=left, seed="), `setup line has the wrong head: ${line}`);

  // Leaf shapes and bloom styles have their own weights, which reach the
  // line; so do the gilt's paint and look.
  for (const name of ["Feather leaves", "Acanthus leaves", "Lance leaves", "Fan blooms", "Round blooms"]) {
    check(await slider(name).count() === 1, `no ${name} slider`);
  }
  await slider("Acanthus leaves").fill("3");
  await slider("Fan blooms").fill("0");
  check(/acanthus=3/.test(await code()) && /fan=0/.test(await code()), `leaf and bloom weights not in the line: ${await code()}`);
  await page.locator("details.gilt").getByRole("button", { name: "Mirror" }).click();
  await slider("Horizon").fill("0.2");
  check(/giltenv=mirror, giltlook=\{horizon=0.2\}/.test(await code()), `gilt look not in the line: ${await code()}`);
  await page.locator("details.gilt").getByRole("button", { name: "vector", exact: true }).click();
  check(/gilt=vector/.test(await code()) && !/giltenv/.test(await code()), `vector gilt not in the line: ${await code()}`);
  await page.locator("details.gilt").getByRole("button", { name: "raster", exact: true }).click();
  await grown();

  // A dark backdrop regrows the page as light ink over a dark sheet, and
  // reaches the line and the copied document's page colour.
  await page.locator("details.backdrop").getByRole("button", { name: "Dark page" }).click();
  await grown();
  check(/backdrop=dark/.test(await code()), `the backdrop is not in the line: ${await code()}`);
  const night = await page.evaluate(() => {
    const sheet = document.querySelector(".sheet");
    const c = sheet.querySelector("canvas");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let bright = 0, dark = 0;
    for (let i = 0; i < d.length; i += 4 * 7) {
      if (d[i + 3] < 128) continue;
      const sum = d[i] + d[i + 1] + d[i + 2];
      if (sum > 450) bright++;
      else if (sum < 150) dark++;
    }
    return { bright, dark, bg: getComputedStyle(sheet).backgroundColor };
  });
  check(night.bg !== "rgb(255, 255, 255)" && night.bright > 2000 && night.bright > night.dark * 3,
    `the dark backdrop does not paint light ink on a dark sheet (${JSON.stringify(night)})`);
  await page.locator("details.backdrop").getByRole("button", { name: "Light paper" }).click();
  await grown();
  check(!/backdrop/.test(await code()), `the light backdrop is still in the line: ${await code()}`);

  // An ornament weight reaches the setup line, and the page regrows.
  await page.locator(".controls details.ornaments .row", { hasText: "Crescent moon" }).locator('input[type="range"]').fill("5");
  await grown();
  check(/ornaments=\{[^}]*moon=5/.test(await code()), `the ornament weight is not in the setup line: ${await code()}`);

  // Randomise sets every part random; a hand-picked ink then survives a spin.
  await page.getByRole("button", { name: "Randomise all inks" }).click();
  await grown();
  check(/hero=random/.test(await code()) && /spin=1/.test(await code()), `randomise is not in the setup line: ${await code()}`);

  // The ink picker shows every ink as a swatch with a plain colour name; it
  // answers the keyboard, and a pick reaches the setup line.
  const leavesRow = page.locator(".controls .row", { has: page.locator(".cap", { hasText: /^Leaves$/ }) });
  const trigger = leavesRow.locator("button.current");
  await trigger.focus();
  await page.keyboard.press("Enter");
  const focused = () => page.evaluate(() => document.activeElement?.getAttribute("role") + ":" + document.activeElement?.textContent.trim().slice(0, 30));
  check(/^option:/.test(await focused()), `opening the picker did not focus an option (${await focused()})`);
  const at0 = await focused();
  await page.keyboard.press("ArrowDown");
  check(/^option:/.test(await focused()) && (await focused()) !== at0, "ArrowDown did not move to the next option");
  await page.keyboard.press("Escape");
  check(await leavesRow.locator("[role=listbox]").count() === 0, "Escape did not close the picker");
  check(await trigger.evaluate((el) => el === document.activeElement), "Escape did not return focus to the picker");
  await trigger.click();
  const inks = await leavesRow.locator(".inks [role=option]").evaluateAll((els) => els.map((el) => ({
    swatch: getComputedStyle(el.querySelector(".ramp")).backgroundImage,
    plain: el.querySelector(".text span").textContent,
  })));
  check(inks.length === 40, `the picker lists ${inks.length} inks, not 40`);
  const bad = inks.find((i) => !/gradient/.test(i.swatch) || !/^(deep |pale )?[a-z -]+$/.test(i.plain));
  check(!bad, `an ink lacks a swatch or a plain name: ${JSON.stringify(bad)}`);
  await leavesRow.locator(".inks [role=option]", { hasText: "momiji" }).click();
  await grown();
  check(/leaves=momiji/.test(await code()), `the picked ink is not in the setup line: ${await code()}`);
  check(/red/.test(await trigger.textContent()), "the picker does not name momiji's colour");
  await page.getByRole("button", { name: "Spin random inks" }).click();
  await grown();
  check(/leaves=momiji/.test(await code()) && /spin=2/.test(await code()), `spinning lost the hand-picked ink: ${await code()}`);

  // The complete document carries the settings and compiles as written.
  await page.getByRole("button", { name: "Copy complete document" }).click();
  const doc = await page.evaluate(() => navigator.clipboard.readText());
  check(doc.includes("\\documentclass") && doc.includes("\\usepackage{tikzflora}") && doc.includes(await code()),
    `the copied document lacks the package or the settings:\n${doc}`);

  // A picture on the home page opens in the viewer at the large copy's
  // resolution; a click zooms it to full size about the point clicked; the
  // arrow keys step through its group; Escape closes it; and the margin
  // garden takes none of it for page content, even laid out again under it.
  {
    const home = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await home.goto(URL);
    await home.waitForFunction(() => window.__floraMargins?.state?.sides?.length === 2, null, { timeout: 10000 }).catch(() => {});
    const sides = () => home.evaluate(() => JSON.stringify(window.__floraMargins?.state?.sides));
    const before = await sides();
    const strip = home.locator(".pages a.enlarge");
    check(await strip.count() === 7 && await home.locator("a.enlarge").count() === 7 + 4 + 4 + 1, `the home page's pictures do not all open the viewer (${await home.locator("a.enlarge").count()})`);
    await strip.nth(1).scrollIntoViewIfNeeded();
    await strip.nth(1).click();
    const img = home.locator("dialog.lightbox[open] img");
    await home.waitForFunction(() => { const i = document.querySelector("dialog.lightbox[open] img"); return i && i.src.endsWith("/img/large/page-2.jpg") && i.complete && i.naturalWidth > 0; }, null, { timeout: 15000 }).catch(() => {});
    const fit = await img.evaluate((i) => ({ src: i.src, natural: i.naturalWidth, w: i.getBoundingClientRect().width, h: i.getBoundingClientRect().height })).catch(() => null);
    check(fit && fit.src.endsWith("/img/large/page-2.jpg") && fit.natural >= 1800, `the viewer does not show the large copy: ${JSON.stringify(fit)}`);
    check(fit && fit.h <= 900 && fit.h > 600, `the viewer does not fit the page to the screen: ${JSON.stringify(fit)}`);
    const box = await img.boundingBox();
    const at = { x: box.x + box.width * 0.6, y: box.y + box.height * 0.35 };
    await home.mouse.click(at.x, at.y);
    await home.waitForTimeout(400);
    const z = await img.boundingBox();
    check(Math.abs(z.width - fit.natural) < 2, `a click does not zoom to full size (${z.width} px)`);
    check(Math.abs((at.x - z.x) / z.width - 0.6) < 0.02 && Math.abs((at.y - z.y) / z.height - 0.35) < 0.02, `the zoom does not keep the clicked point under the pointer (${JSON.stringify(z)})`);
    // A window resized while the viewer is open lays the garden out again,
    // and the viewer's caption and buttons near the edges are not content.
    await home.setViewportSize({ width: 1400, height: 900 });
    await home.waitForTimeout(1500);
    const open = await home.evaluate(() => window.__floraMargins?.state?.sides?.map((sd) => sd.m) ?? []);
    check(open.length === 2 && open.every((m) => m >= 110), `the open viewer is taken for page content: margins ${JSON.stringify(open)}`);
    await home.setViewportSize({ width: 1440, height: 900 });
    await home.waitForTimeout(1500);
    await home.keyboard.press("ArrowRight");
    await home.waitForFunction(() => document.querySelector("dialog.lightbox[open] img")?.src.includes("page-3.jpg"), null, { timeout: 5000 }).catch(() => {});
    check((await img.getAttribute("src")).includes("page-3.jpg"), `the right arrow does not step to the next page: ${await img.getAttribute("src")}`);
    await home.keyboard.press("Escape");
    check(await home.locator("dialog.lightbox[open]").count() === 0, "Escape does not close the viewer");
    check(await sides() === before, `the viewer changes the margin garden: ${before} -> ${await sides()}`);
    await home.close();
  }

  // Each layout button grows its own layout, whatever its baked page was
  // laid out as: the Title button's page is the example document's flank
  // title page, grown as a title crown (no plant down the left side), and
  // the Flank button's page grows one.
  {
    const leftInk = async (layout) => {
      const m = await browser.newPage({ viewport: { width: 1440, height: 900 } });
      await m.goto(`${MIXER}?layout=${layout}`);
      await m.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
      const ink = await m.evaluate(() => {
        const c = document.querySelector(".sheet canvas");
        const d = c.getContext("2d").getImageData(0, Math.round(c.height * 0.45), Math.round(c.width * 0.2), Math.round(c.height * 0.3)).data;
        let n = 0, k = 0;
        for (let i = 3; i < d.length; i += 16) { k++; if (d[i] > 40) n++; }
        return n / k;
      });
      await m.close();
      return ink;
    };
    const title = await leftInk("title"), flank = await leftInk("flank");
    check(title < 0.02, `the mixer's Title page grows down its left side (${title.toFixed(3)}): not a title crown`);
    check(flank > 0.05, `the mixer's Flank page has no plant up its left side (${flank.toFixed(3)})`);
  }

  // The home page shows the four seasons; one opens in the mixer, which
  // names it in the setup line, and one changed ink follows it there.
  await page.goto(URL);
  check(await page.locator(".ways figure").count() === 4, "the home plate does not show four seasons");
  await page.locator(".ways figure").nth(1).getByRole("link", { name: "Use these inks" }).click();
  await page.waitForURL(/\/mixer\/\?way=summer$/);
  await page.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
  check(/seed=83,/.test(await code()) && /colourway=summer\}$/.test(await code()), `summer did not load: ${await code()}`);
  check(await page.getByRole("button", { name: "Summer" }).getAttribute("aria-pressed") === "true", "the Summer button is not marked");
  const heroPick = page.locator(".controls .row", { has: page.locator(".cap", { hasText: /^Main flower$/ }) });
  await heroPick.locator("button.current").click();
  await heroPick.locator(".inks [role=option]", { hasText: "momiji" }).click();
  await grown();
  check(/colourway=summer, palette=\{hero=momiji\}/.test(await code()), `a changed ink is not written after the colourway: ${await code()}`);

  // The home page shows the four title pages; one opens its layout in the
  // mixer, which grows it and writes a lettered title page for it.
  await page.goto(URL);
  check(await page.locator(".titles figure").count() === 4, "the home page does not show four title pages");
  await page.locator(".titles figure").nth(1).getByRole("link", { name: "Try it" }).click();
  await page.waitForURL(/\/mixer\/\?layout=wreath$/);
  await page.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
  check((await code()).startsWith("\\florasetup{layout=wreath, seed="), `the wreath did not load: ${await code()}`);
  check(await page.getByRole("radio", { name: "Wreath" }).isChecked(), "the Wreath layout is not chosen");
  const wreath = await inked();
  check(wreath.n > original.n * 0.3, `the wreath page is nearly bare (${wreath.n} inked samples)`);
  await page.getByRole("button", { name: "Copy complete document" }).click();
  const titleDoc = await page.evaluate(() => navigator.clipboard.readText());
  check(titleDoc.includes("\\begin{floratitle}") && titleDoc.includes("\\floraletters") && titleDoc.includes("\\floraoff"),
    `the wreath's document is not a lettered title page:\n${titleDoc}`);
  // Its lettering's style, arch and ink: the baked page for that style and
  // arch is shown, the lettering is filled with the ink, and the document
  // letters the title so.
  await page.getByRole("button", { name: "outline", exact: true }).click();
  await page.getByRole("button", { name: "Strong arch" }).click();
  await page.locator(".controls select").selectOption("kon-peki");
  await grown();
  check((await page.locator(".sheet img").getAttribute("src")).endsWith("/bake/text-12-outline-40.png"), "the outline, strong-arch page is not shown");
  const fill = await page.locator(".sheet .letters").evaluate((el) => [getComputedStyle(el).backgroundColor, getComputedStyle(el).maskImage]);
  check(fill[0] !== "rgb(0, 0, 0)" && fill[0].startsWith("rgb") && fill[1].includes("letters-12-outline-40.png"), `lettering not filled with the ink: ${fill}`);
  await page.getByRole("button", { name: "Copy complete document" }).click();
  const lettered = await page.evaluate(() => navigator.clipboard.readText());
  check(lettered.includes("\\floraletters[style=outline, arch=40, ink=kon-peki]"), `the document does not letter the title as chosen:\n${lettered}`);

  // The gallery opens on the flourishes, labelled, once it scrolls near;
  // the All tab draws every ornament kind.
  const sample = () => page.evaluate(() => {
    const c = document.querySelector(".plate canvas");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let n = 0;
    for (let i = 0; i < d.length; i += 4 * 11) if (d[i + 3] > 0 && d[i] + d[i + 1] + d[i + 2] < 600) n++;
    const box = document.querySelector(".plate").getBoundingClientRect();
    const tags = [...document.querySelectorAll(".plate .tag")];
    const out = tags.filter((t) => { const r = t.getBoundingClientRect(); return r.left < box.left - 1 || r.top < box.top - 1; });
    return { n, tags: tags.length, out: out.map((t) => t.textContent.trim()), names: tags.map((t) => t.querySelector("code").textContent) };
  });
  await page.goto(ORNAMENTS);
  await page.locator("#gallery .count", { hasText: /\d+ kinds/ }).waitFor({ timeout: 120000 });
  const flourishes = await sample();
  check(flourishes.names.includes("copperplate") && flourishes.names.includes("rinceau") && !flourishes.names.includes("night"),
    `the flourish tab labels: ${flourishes.names.join(", ")}`);
  check(await page.locator("#gallery .about").textContent() !== "", "the flourish tab does not say what a flourish is");
  await page.locator("#gallery .tabs").getByRole("tab", { name: "All" }).click();
  await page.locator("#gallery .count", { hasText: new RegExp(`^(?!${flourishes.tags} kinds)\\d+ kinds`) }).waitFor({ timeout: 120000 });
  const plate = await sample();
  check(plate.n > 3000, `the gallery shows too little (${plate.n} inked samples)`);
  check(plate.tags >= 36 && plate.names.includes("cul_de_lampe") && plate.names.includes("night"), `the gallery labels ${plate.tags} kinds: ${plate.names.join(", ")}`);
  check(plate.out.length === 0, `gallery labels fall outside the sheet: ${plate.out.join("; ")}`);

  // The vector relief, the mirror look and a changed key of the look
  // (?giltlook=, as \florasetup's giltlook) each change the gallery's gold.
  const allKinds = async (p) => {
    await p.locator("#gallery").scrollIntoViewIfNeeded();
    await p.locator("#gallery .count", { hasText: /\d+ kinds/ }).waitFor({ timeout: 120000 });
    await p.locator("#gallery .tabs").getByRole("tab", { name: "All" }).click();
    await p.locator("#gallery .count", { hasText: `${plate.tags} kinds` }).waitFor({ timeout: 120000 });
    return pixels(p, ".plate canvas");
  };
  const gallery = await pixels(page, ".plate canvas");
  for (const [q, label] of [["?gilt=vector", "vector gilt"], ["?giltenv=mirror", "mirror gilt"], ["?giltlook=ground=0,sky=0.3", "darker gilt"]]) {
    const alt = await context.newPage();
    await alt.goto(ORNAMENTS + q);
    const { differ, ink } = compare(gallery, await allKinds(alt));
    await alt.close();
    console.log(`${label} gallery: ${differ} of ${ink} inked samples differ from the default`);
    check(differ > ink * 0.02, `${label} drew the same gallery as the default (${differ} of ${ink} samples differ)`);
  }

  // The site is watercolour on paper whatever the visitor's colour scheme:
  // a dark-scheme browser gets the same paper page, and the gallery's sheet
  // stays white.
  const paperBg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  await page.emulateMedia({ colorScheme: "dark" });
  const darkBg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  check(darkBg === paperBg, `a dark-scheme browser gets ${darkBg}, not the paper ${paperBg}`);
  const sheetBg = await page.evaluate(() => getComputedStyle(document.querySelector(".plate")).backgroundColor);
  check(sheetBg === "rgb(255, 255, 255)", `the gallery sheet is ${sheetBg} in a dark-scheme browser`);
  await page.emulateMedia({ colorScheme: "light" });

  // The guide's tables and its every-option list come from the package
  // (catalog.json): settings added since the guide was written are listed,
  // and so are the leaf shapes, gilt look keys and lettering styles.
  await page.goto(URL + PAGES.guide);
  await page.locator("#g-reference ~ dl.ref").first().waitFor();
  const guide = await page.locator("main").textContent();
  for (const word of ["giltlook", "cache", "feather", "acanthus", "horizon", "window_top", "engraved", "scrollwork", "kon-peki", "cul_de_lampe"]) {
    check(guide.includes(word), `the guide does not list ${word}`);
  }

  // Phones: no page scrolls sideways, and the mixer's page stays in view
  // while the inks are chosen.
  const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
  phone.on("pageerror", (e) => errors.push(String(e)));
  for (const [name, path] of Object.entries(PAGES)) {
    await phone.goto(URL + path);
    const wide = await phone.evaluate(() => document.documentElement.scrollWidth);
    check(wide <= 390, `the ${name} page scrolls sideways on a phone (${wide}px)`);
  }
  await phone.goto(MIXER);
  await phone.locator(".status", { hasText: "Grown in" }).waitFor({ timeout: 120000 });
  const heroRow = phone.locator(".controls .row", { has: phone.locator(".cap", { hasText: /^Main flower$/ }) });
  await heroRow.scrollIntoViewIfNeeded();
  await heroRow.locator("button.current").click();
  const sheet = await phone.evaluate(() => document.querySelector(".sheet").getBoundingClientRect().toJSON());
  check(sheet.top >= 0 && sheet.bottom <= 844 * 0.5, `the phone page is not kept in view (${JSON.stringify(sheet)})`);
  const panelBox = await heroRow.locator("[role=listbox]").boundingBox();
  check(panelBox && panelBox.width >= 300, "the phone picker does not open across the controls");
  await phone.close();
  check(errors.length === 0, "page errors: " + errors.join("; "));
} finally {
  if (browser) await browser.close();
  server?.kill();
}
if (failures) {
  console.error(`site: ${failures} failure(s)`);
  process.exit(1);
}
console.log("site: ok");
