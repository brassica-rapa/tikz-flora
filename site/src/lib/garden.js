// A garden for a web page, grown in the visitor's browser and set by their
// own clock: the date picks the garden, so everyone sees the same one that
// day; the hour how far it has grown; the month and hemisphere its
// colourway. lua/flora/garden.lua lays it out; render.worker.js grows it.
//
//   const garden = createGarden();
//   const { bitmap } = await garden.grow({ mode: "margins", width, height,
//     x0, x1, dpr: devicePixelRatio, settings: "backdrop=dark" });
//
// Only this module and the worker load; pdf.js is not needed.

// How far the garden has grown at hour `h` (0-23, local): a seedling
// overnight, opening from dawn and in full bloom by mid-afternoon, held
// through the evening.
export const DAWN = 5, FULL = 15, NIGHT = 0.04;
export function growAt(h) {
  if (!(h >= 0 && h < 24)) throw new RangeError(`hour ${h} is not 0-23`);
  if (h < DAWN) return NIGHT;
  if (h >= FULL) return 1;
  const t = (h - DAWN) / (FULL - DAWN);
  return NIGHT + (1 - NIGHT) * t * t * (3 - 2 * t);
}

// Time zones south of the equator, by prefix or exact name. Seasons near
// the equator barely turn, so a tropical zone on either list does little
// harm.
const SOUTH = [
  "Australia/", "Antarctica/", "America/Argentina/", "Pacific/Auckland", "Pacific/Chatham", "Pacific/Fiji",
  "Pacific/Noumea", "Pacific/Tongatapu", "Pacific/Efate", "Pacific/Norfolk", "America/Sao_Paulo",
  "America/Santiago", "America/Montevideo", "America/Asuncion", "America/La_Paz", "America/Lima",
  "America/Punta_Arenas", "Africa/Johannesburg", "Africa/Maputo", "Africa/Harare", "Africa/Windhoek",
  "Africa/Lusaka", "Africa/Gaborone", "Africa/Maseru", "Africa/Mbabane", "Africa/Blantyre", "Africa/Luanda",
  "Indian/Mauritius", "Indian/Reunion", "Indian/Antananarivo", "Atlantic/Stanley",
];
export function southern(timeZone) {
  return SOUTH.some((z) => (z.endsWith("/") ? timeZone.startsWith(z) : timeZone === z));
}

// The colourway (tikz-flora's seasonal ones) of month `m` (1-12).
const SEASONS = ["winter", "winter", "spring", "spring", "spring", "summer", "summer", "summer", "autumn", "autumn", "autumn", "winter"];
export function seasonAt(m, south = false) {
  if (!(m >= 1 && m <= 12)) throw new RangeError(`month ${m} is not 1-12`);
  return SEASONS[(m - 1 + (south ? 6 : 0)) % 12];
}

// The garden at instant `date` in time zone `timeZone` (the visitor's own
// by default): { seed, grow, colourway, hour, day }. `day` (YYYY-MM-DD)
// and `hour` are local; the garden changes only when one of them does.
export function gardenAt(date = new Date(), timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23",
  }).formatToParts(date).map((p) => [p.type, p.value]));
  const hour = Number(parts.hour), month = Number(parts.month);
  return {
    day: `${parts.year}-${parts.month}-${parts.day}`,
    hour,
    seed: Number(`${parts.year}${parts.month}${parts.day}`),
    grow: growAt(hour),
    colourway: seasonAt(month, southern(timeZone)),
  };
}

// The worker: one per garden, started on first use.
function client(makeWorker) {
  let worker, next = 0;
  const waiting = new Map();
  return (msg) => {
    worker ||= (() => {
      const w = makeWorker();
      w.onmessage = (e) => {
        const p = waiting.get(e.data.id);
        waiting.delete(e.data.id);
        if (!p) return;
        if (e.data.error) p.reject(new Error(e.data.error));
        else p.resolve(e.data);
      };
      w.onerror = (e) => {
        for (const p of waiting.values()) p.reject(new Error(e.message || "garden worker failed"));
        waiting.clear();
      };
      return w;
    })();
    const id = ++next;
    return new Promise((resolve, reject) => {
      waiting.set(id, { resolve, reject });
      worker.postMessage({ ...msg, id });
    });
  };
}

const CACHE = "flora-garden";
// Gardens kept besides the one just grown: enough for a few window sizes.
const KEEP = 4;

// A garden grower. grow(o) resolves to { bitmap, cached, ms, at }, plus
// `renderer` and `drawMs` (draw.js) when it grew afresh:
//   o.mode       "margins" or "band" (lua/flora/garden.lua)
//   o.width, o.height  CSS px; o.x0, o.x1 the content column (margins)
//   o.dpr        device pixels per CSS px (default 1)
//   o.settings   \florasetup keys over the garden's own, e.g. "backdrop=dark"
//   o.date, o.timeZone  the clock (default: now, the visitor's zone)
//   o.cache      false to skip the Cache Storage copy (default true)
//   o.renderer   "webgl" (default, the 2D canvas where WebGL2 is missing) or
//                "canvas2d"
// The colourway follows the season unless o.settings names its own.
export function createGarden({ worker } = {}) {
  const post = client(worker ?? (() => new Worker(new URL("./render.worker.js", import.meta.url), { type: "module" })));
  let version;
  async function grow(o) {
    const at = gardenAt(o.date ?? new Date(), o.timeZone);
    const dpr = Math.min(3, Math.max(1, o.dpr ?? 1));
    const own = o.settings ?? "";
    const settings = /(^|,)\s*colourway\s*=/.test(own) ? own : [`colourway=${at.colourway}`, own].filter(Boolean).join(", ");
    const garden = { mode: o.mode, width: Math.round(o.width), height: Math.round(o.height), seed: at.seed, grow: at.grow, settings };
    if (o.mode === "margins") Object.assign(garden, { x0: Math.round(o.x0), x1: Math.round(o.x1) });
    const px = Math.round(garden.width * dpr);
    const useCache = o.cache !== false && typeof caches !== "undefined";
    version ??= (await post({ kind: "version" })).version;
    const key = new URL(`/__flora-garden/${version}/${encodeURIComponent(JSON.stringify({ ...garden, px }))}`, globalThis.location?.href ?? "http://localhost/").href;
    if (useCache) {
      try {
        const hit = await (await caches.open(CACHE)).match(key);
        if (hit) return { bitmap: await createImageBitmap(await hit.blob()), cached: true, ms: 0, at };
      } catch { /* no cache in this context: grow it */ }
    }
    const out = await post({ kind: "garden", garden, px, png: useCache, draw: o.renderer });
    if (useCache && out.png) {
      try {
        const cache = await caches.open(CACHE);
        await cache.put(key, new Response(out.png, { headers: { "content-type": "image/png" } }));
        const keys = await cache.keys();
        for (const req of keys.slice(0, Math.max(0, keys.length - 1 - KEEP))) if (req.url !== key) await cache.delete(req);
      } catch { /* storage full or denied: the garden still shows */ }
    }
    return { bitmap: out.bitmap, cached: false, ms: out.ms, at, renderer: out.renderer, drawMs: out.drawMs };
  }
  return { grow };
}
