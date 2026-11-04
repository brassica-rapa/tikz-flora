<script>
  // The tuner. The page is built from components (lua/flora/components.lua),
  // each owning some of tune.lua's settings. Pick a component to tune its
  // dials and size curves against a specimen of it alone; every change
  // also rolls up into the page, rendered beside the de-warped reference.
  // All settings live in one tune tree, kept in this browser between visits.
  import { onMount } from "svelte";
  import { DialRoot } from "dialkit/svelte";
  import Dials from "./lib/Dials.svelte";
  import Curve from "./lib/Curve.svelte";
  import Specimen from "./lib/Specimen.svelte";
  import Swatches from "./lib/Swatches.svelte";
  import { buildPanel, applyDials, curvesIn, describe, clone, getPath, setPath, docFor, isCurve, setChoices, setBounds } from "./lib/tune.js";

  const STORE = "flora-tune";

  let tune = $state(null);
  let defaults = null;
  let doc = $state({});
  let components = $state([]);
  let current = $state("hero");
  let generation = $state(0);
  let seed = $state(1);
  let page = $state(1);
  let auto = $state(true);
  let status = $state("Loading tune.lua…");
  let failed = $state(false);
  let render = $state({ png: "", text: "", label: "Render", busy: false });

  const say = (msg, err = false) => { status = msg; failed = err; };
  const comp = $derived(components.find((c) => c.id === current));
  const values = $derived(tune ? JSON.stringify($state.snapshot(tune)) : "");
  const panel = $derived(tune && comp ? buildPanel($state.snapshot(tune), doc, comp.paths) : null);
  const curves = $derived(tune && comp ? curvesIn(tune, comp.paths) : []);
  const looks = $derived.by(() => {
    if (!tune || !comp) return [];
    const all = Object.keys(tune.color.looks);
    if (comp.paths.some((p) => p === "color" || p.startsWith("color.hue"))) return all;
    return all.filter((l) => comp.paths.includes(`color.looks.${l}`));
  });
  const guide = $derived(tune && comp ? describe(tune, doc, comp.paths) : []);

  // Saved settings are taken only where they still fit tune.lua's shape,
  // so renamed or removed settings fall back to their defaults.
  function restore(base, saved) {
    if (saved === undefined || saved === null) return base;
    if (isCurve(base)) return isCurve(saved) ? saved : base;
    if (Array.isArray(base)) return Array.isArray(saved) && saved.length === base.length ? saved : base;
    if (base && typeof base === "object") {
      const out = {};
      for (const k of Object.keys(base)) out[k] = restore(base[k], saved[k]);
      return out;
    }
    return typeof saved === typeof base ? saved : base;
  }

  async function loadDefaults() {
    const { _doc, _choices, _bounds, ...shape } = await (await fetch("/api/tune")).json();
    setChoices(_choices);
    setBounds(_bounds);
    defaults = shape;
    doc = _doc || {};
    return shape;
  }

  onMount(async () => {
    try {
      const shape = await loadDefaults();
      components = await (await fetch("/api/components")).json();
      let saved = null;
      try { saved = JSON.parse(localStorage.getItem(STORE) || "null"); } catch { /* storage unavailable */ }
      tune = restore(clone(shape), saved);
      say("Ready.");
    } catch (e) {
      say(`Could not load: ${e.message || e}`, true);
    }
  });

  $effect(() => {
    if (!values) return;
    try { localStorage.setItem(STORE, values); } catch { /* not kept between visits */ }
  });

  function onDials(v) {
    if (panel) applyDials(tune, panel.entries, v);
  }
  function onCurve(path, curve) {
    setPath(tune, path, curve);
  }

  // One page render in flight; a change meanwhile triggers one more.
  let inFlight = false, again = false;
  async function renderPage(full = false) {
    if (inFlight) { again = true; return; }
    inFlight = true;
    again = false;
    render.busy = true;
    say(full ? `Compiling page ${page}, seed ${seed} with LuaLaTeX…` : `Drawing page ${page}, seed ${seed}…`);
    try {
      const res = await fetch("/api/render", { method: "POST",
        body: JSON.stringify({ values: JSON.parse(values), seed, page, full }) });
      const out = await res.json();
      if (!res.ok) throw new Error(out.error);
      render = { png: out.png, text: out.text || "", busy: false,
        label: `${full ? "LuaLaTeX" : "Preview"}, page ${page}, seed ${seed} (${out.seconds} s)` };
      say("Ready.");
    } catch (e) {
      render.busy = false;
      say(String(e.message || e), true);
    }
    inFlight = false;
    if (again) renderPage();
  }
  $effect(() => {
    if (!values || !auto) return;
    void seed; void page;
    const timer = setTimeout(() => renderPage(), 700);
    return () => clearTimeout(timer);
  });

  function resetComponent() {
    for (const p of comp.paths) setPath(tune, p, clone(getPath(defaults, p)));
    generation++;
  }
  function resetAll() {
    tune = clone(defaults);
    generation++;
  }
  async function post(url, okMsg) {
    const res = await fetch(url, { method: "POST", body: JSON.stringify({ values: JSON.parse(values) }) });
    const out = await res.json();
    if (!res.ok) return say(out.error, true);
    say(okMsg(out));
    return out;
  }
  const saveLocal = () => post("/api/save", (o) => `Saved to ${o.saved}. just build now uses these values.`);
  async function writeDefaults() {
    const out = await post("/api/bake", (o) => o.changed.length
      ? `Wrote ${o.changed.length} setting${o.changed.length === 1 ? "" : "s"} into lua/flora/tune.lua.${o.local ? " tune-local.lua still overrides some of them." : ""}`
      : "tune.lua already has these values.");
    if (out) await loadDefaults();
  }

  // The reference and the render are aligned on the running-head rule: the
  // rectified photo shows 70 pt above its rule (row 154 at 0.456 pt per
  // pixel, tex/reference/viewport.json); the reference page's rule is 115.3 pt
  // below its top. The view ends where the photo does, at the page's foot.
  const PX_PER_PT = 1.15;
  const SHIFT_PT = 115.3 - 154 * 0.456;
  const VIEW = [250, 1754 * 0.456];
</script>

<div class="app">
  <nav>
    <h1>Flora tuner</h1>
    {#each components as c}
      <button class="part" class:on={c.id === current} onclick={() => { current = c.id; }}>
        <span class="name">{c.label}</span>
        <span class="muted small">{c.desc}</span>
      </button>
    {/each}
  </nav>

  <section class="controls">
    {#if comp && tune}
      <h2>{comp.label}</h2>
      <p class="muted">{comp.desc}</p>
      <div class="buttons">
        <button onclick={resetComponent}>Reset {comp.label.toLowerCase()}</button>
      </div>
      {#key `${current}:${generation}`}
        {#if panel && Object.keys(panel.config).length}
          <Dials name={comp.label} config={panel.config} onvalues={onDials} />
        {/if}
        <DialRoot mode="inline" theme="system" productionEnabled={true} />
        {#each curves as path}
          <Curve curve={getPath(tune, path)} label={(docFor(doc, path) || [path])[0]}
                 text={(docFor(doc, path) || ["", ""])[1]} onchange={(c) => onCurve(path, c)} />
        {/each}
      {/key}
      {#if looks.length}
        <h3>Ramp range</h3>
        <Swatches color={tune.color} {looks} />
      {/if}
      {#if guide.length}
        <details class="guide">
          <summary>What each setting does</summary>
          <dl>
            {#each guide as g}
              <dt style="padding-left: {g.depth * 12}px">{g.label}{g.range ? " (range, picked per shape)" : ""}{g.curve ? " (curve)" : ""}</dt>
              <dd style="padding-left: {g.depth * 12}px">{g.text}</dd>
            {/each}
          </dl>
        </details>
      {/if}
    {/if}
  </section>

  <section class="renders">
    <div class="toolbar">
      <label>Seed <input type="number" min="1" max="999" bind:value={seed}></label>
      <label>Page <select bind:value={page}><option value={1}>1</option><option value={2}>2</option></select></label>
      <label><input type="checkbox" bind:checked={auto}> Auto preview</label>
      <button onclick={() => renderPage(false)} title="Draw the flora now without TeX over the cached text page.">Preview</button>
      <button onclick={() => renderPage(true)} title="Compile the page with LuaLaTeX exactly as just build would.">Full render</button>
      <button onclick={saveLocal} title="Write these values to tune-local.lua; just build applies it on top of tune.lua.">Save to tune-local.lua</button>
      <button onclick={writeDefaults} title="Write the changed values into lua/flora/tune.lua itself, keeping its comments and layout.">Write into tune.lua</button>
      <button onclick={resetAll} title="Return every setting to tune.lua's values.">Reset all</button>
    </div>
    <div class="status" class:err={failed}>{status}</div>
    {#if comp?.specimen && tune}
      <Specimen component={comp} {values} {seed} />
    {/if}
    <div class="compare">
      <figure>
        <div class="frame" style="width: {VIEW[0] * PX_PER_PT}px; height: {VIEW[1] * PX_PER_PT}px">
          <img src="/tex/reference/rectified.png" alt="De-warped reference margin" style="width: {1389 * 0.456 * PX_PER_PT}px">
        </div>
        <figcaption class="muted">Reference, de-warped</figcaption>
      </figure>
      <figure class:busy={render.busy}>
        <div class="frame" style="width: {VIEW[0] * PX_PER_PT}px; height: {VIEW[1] * PX_PER_PT}px">
          {#if render.png}
            <img src={render.png} alt="Rendered margin" style="width: {595.28 * PX_PER_PT}px; top: {-SHIFT_PT * PX_PER_PT}px">
            {#if render.text}
              <img class="text" src={render.text} alt="" style="width: {595.28 * PX_PER_PT}px; top: {-SHIFT_PT * PX_PER_PT}px">
            {/if}
          {/if}
        </div>
        <figcaption class="muted">{render.label}</figcaption>
      </figure>
    </div>
  </section>
</div>
