<script>
  import { onMount } from "svelte";
  import { meta as loadMeta, render, show, px, drawnBy } from "./render.js";
  import { setupLine, documentFor, TITLE_PAGES, ARCHES } from "./setup.js";
  import InkPicker from "./InkPicker.svelte";
  import COLOURWAYS from "./colourways.json";
  import { face } from "./ink.js";

  const query = new URLSearchParams(globalThis.location?.search ?? "");
  // What each palette part is called here; the setup line keeps the key.
  const PART_LABEL = {
    hero: "Main flower", blooms: "Blooms", leaves: "Leaves", leaflets: "Leaflets", stems: "Stems",
    sprays: "Sprays", ghost: "Ghost bloom", cartouche: "Cartouche",
  };

  let meta = $state(null);
  let pages = $state([]);
  let layout = $state(0);
  let seed = $state(COLOURWAYS[0].seed);
  let mix = $state({});
  let ornaments = $state({});
  let palette = $state({});
  let spin = $state(0);
  // Gilt, as \florasetup's gilt, giltenv and giltlook; ?gilt=vector,
  // ?giltenv=mirror and ?giltlook=horizon=0.1,grain=0 open on them.
  let gilt = $state(query.get("gilt") === "vector" ? "vector" : "raster");
  let giltenv = $state(query.get("giltenv") === "mirror" ? "mirror" : "studio");
  let giltlook = $state(Object.fromEntries((query.get("giltlook") ?? "").split(",").map((kv) => kv.split("="))
    .filter(([k, v]) => k && v !== undefined && Number.isFinite(Number(v))).map(([k, v]) => [k.trim(), Number(v)])));
  // What the page is painted over, as \florasetup's backdrop; ?backdrop=dark
  // opens on a dark page.
  let backdrop = $state(query.get("backdrop") === "dark" ? "dark" : "light");
  // The title lettering of the four title-page layouts (\floraletters).
  let letters = $state({ style: "engraved", arch: 20, ink: "black" });
  let status = $state("Loading the generator…");
  let busy = $state(false);
  // The bar along the sheet's foot: running while the generator loads
  // (`loading`), then how far each grow has got (0 to 1).
  let loading = $state(true);
  let progress = $state(0);
  let copied = $state("");
  let canvas, frame;
  const specs = new Map();
  let timer, again = false;

  const label = (k) => meta?.kinds.find((x) => x[0] === k)?.[1] ?? k;
  const hint = (k) => meta?.kinds.find((x) => x[0] === k)?.[2] ?? "";
  // The mix's kinds in the catalog's groups; density has its own slider.
  let groups = $derived(meta ? meta.catalog.mix.filter((g) => g.group !== "Overall")
    .map((g) => ({ title: g.group, keys: g.kinds.map((k) => k.key) })) : []);
  // The gilt look's keys for the look in use, with their defaults there.
  let lookKeys = $derived(meta ? meta.catalog.gilt.keys.filter((k) => !k.look || k.look === giltenv) : []);
  let lettered = $derived(pages.length > 0 && TITLE_PAGES.has(pages[layout].layout));
  // A title page's baked text and layout depend on its lettering's style
  // and arch: one bake of each (just site-bake).
  let variant = $derived(pages.length ? (lettered ? `${pages[layout].page}-${letters.style}-${letters.arch}` : `${pages[layout].page}`) : "");
  let letterInk = $derived(meta?.catalog.letters.inks[letters.ink] ?? "#000");
  let lookLine = $derived(Object.entries(giltlook).map(([k, v]) => `${k}=${v}`).join(", "));
  let line = $derived(meta && pages.length ? setupLine({ layout: pages[layout].layout, seed, mix, ornaments, palette, spin, gilt, giltenv, giltlook, backdrop }, meta) : "");
  let anyRandom = $derived(Object.values(palette).includes("random"));
  // The colourway the inks and seed match now, if any (-1 for the
  // package's own look).
  let current = $derived.by(() => {
    if (!meta) return null;
    const same = (p) => meta.parts.every(([k, d]) => (palette[k] ?? d) === (p[k] ?? d));
    if (same(Object.fromEntries(meta.parts))) return -1;
    return COLOURWAYS.findIndex((c) => c.seed === seed && same(meta.colourways[c.key]));
  });

  onMount(start);

  async function start() {
    try {
      const [m, man] = await Promise.all([loadMeta(), fetch("/bake/manifest.json").then((r) => r.json())]);
      meta = m;
      pages = man;
      mix = Object.fromEntries(m.kinds.map(([k, , , d]) => [k, d]));
      ornaments = Object.fromEntries(m.ornaments.flatMap((s) => s.kinds.map(([k, , d]) => [k, d])));
      // Visitors start on here, so the mixer shows them.
      for (const k of ["bee", "butterfly", "bird", "snail"]) mix[k] = 1;
      palette = { ...Object.fromEntries(m.parts), ...m.colourways[COLOURWAYS[0].key] };
      // ?way=spring opens on that colourway, as its "Use these inks" link
      // asks, and ?layout=wreath on that layout's page.
      const params = new URLSearchParams(location.search);
      const way = COLOURWAYS.findIndex((c) => c.key === params.get("way"));
      const lay = pages.findIndex((p) => p.layout === params.get("layout"));
      // A colourway regrows after its pause, on whatever layout is set by then.
      if (way > 0) useColourway(way);
      if (lay >= 0) layout = lay;
      if (way <= 0) grow();
    } catch (e) {
      status = `The mixer could not start: ${e.message}`;
    }
    loading = false;
  }

  async function spec(p) {
    if (!specs.has(p)) {
      const r = await fetch(`/bake/spec-${p}.lua`);
      if (!r.ok) throw new Error(`no baked page ${p}`);
      specs.set(p, await r.text());
    }
    return specs.get(p);
  }

  async function grow() {
    if (!meta) return;
    if (busy) { again = true; return; }
    busy = true;
    const pg = pages[layout];
    status = "Growing…";
    progress = 0;
    try {
      const job = { spec: await spec(variant), layout: pg.layout, seed, page: pg.page, mix: $state.snapshot(mix), ornaments: $state.snapshot(ornaments), palette: $state.snapshot(palette), spin, px: px(frame.clientWidth), gilt, giltenv, giltlook: lookLine, backdrop };
      const out = await render(job, (f) => { progress = Math.max(progress, f); });
      await show(out, canvas, frame.clientWidth);
      progress = 1;
      status = `Grown in ${(out.ms / 1000).toFixed(1)} s (${drawnBy(out)})`;
    } catch (e) {
      status = `Something went wrong: ${e.message}`;
    }
    busy = false;
    if (again) { again = false; grow(); }
  }

  function changed() {
    clearTimeout(timer);
    timer = setTimeout(grow, 500);
  }

  // A colourway's inks and seed on the left-margin page, as baked on the
  // site's opening; i = -1 restores the package's own look.
  function useColourway(i) {
    if (!meta) return;
    const defaults = Object.fromEntries(meta.parts);
    if (i < 0) {
      palette = defaults;
    } else {
      palette = { ...defaults, ...meta.colourways[COLOURWAYS[i].key] };
      seed = COLOURWAYS[i].seed;
      layout = Math.max(0, pages.findIndex((p) => p.layout === "left"));
    }
    spin = 0;
    changed();
  }

  // Every part to a random ink, and a new draw of them.
  function randomiseAll() {
    for (const [part] of meta.parts) palette[part] = "random";
    spin += 1;
    changed();
  }

  // New inks for the parts already set to random; the rest stay.
  function spinRandom() {
    spin += 1;
    changed();
  }

  function reroll() {
    seed = Math.floor(Math.random() * 9999) + 1;
    changed();
  }

  // A gilt look key to `v`; at the look's default it is dropped again.
  function setLook(k, v) {
    if (v === k.defaults[giltenv]) delete giltlook[k.key];
    else giltlook[k.key] = v;
    changed();
  }

  // Keys belong to one look, so a new look starts from its own defaults.
  function setEnv(env) {
    giltenv = env;
    giltlook = {};
    changed();
  }

  async function copy(what) {
    const text = what === "document" ? documentFor(line, pages[layout].layout, letters, backdrop === "dark" ? meta.catalog.backdrop.dark : undefined) : line;
    await navigator.clipboard.writeText(text);
    copied = what;
    setTimeout(() => (copied = ""), 1600);
  }

  // A colourway shown by the inks of its main parts.
  const swatches = (c) => ["hero", "blooms", "leaves", "sprays"].map((k) => meta.colourways[c.key][k]);
  const swatch = (ink) => (meta?.ramps[ink] ? face(meta.ramps[ink]) : meta?.groupInks[ink] ? face(meta.ramps[meta.groupInks[ink][0]]) : "transparent");
</script>

<div class="mixer">
  <div class="controls">
    <h1>The mixer</h1>
    <p class="note">The package's own Lua, running in your browser on a page
      of the example.</p>
    {#if meta}
      <fieldset class="layouts">
        <legend class="sc">Layout</legend>
        {#each pages as p, i}
          <label class:on={layout === i}>
            <input type="radio" name="layout" value={i} checked={layout === i}
              onchange={() => { layout = i; changed(); }}>{p.label}
          </label>
        {/each}
      </fieldset>

      {#if lettered}
        <h2 class="sc">Title lettering</h2>
        <p class="hint">The title is drawn from the font's outlines with
          <code>\floraletters</code>.</p>
        <div class="choices" role="group" aria-label="Lettering style">
          {#each meta.catalog.letters.styles as st}
            <button type="button" title={st.about} aria-pressed={letters.style === st.name}
              onclick={() => { letters.style = st.name; changed(); }}>{st.name}</button>
          {/each}
        </div>
        <div class="choices" role="group" aria-label="Arch">
          {#each ARCHES as [deg, name]}
            <button type="button" aria-pressed={letters.arch === deg}
              onclick={() => { letters.arch = deg; changed(); }}>{name}</button>
          {/each}
        </div>
        <label class="row">
          <span>Ink</span>
          <select bind:value={letters.ink}>
            <option value="black">black</option>
            {#each meta.catalog.inks as ink}<option value={ink}>{ink}</option>{/each}
          </select>
          <i class="chip" style:background={letterInk}></i>
        </label>
      {/if}

      <h2 class="sc">Colourway</h2>
      <div class="ways" role="group" aria-label="Colourways">
        {#each COLOURWAYS as c, i}
          <button type="button" aria-pressed={current === i} onclick={() => useColourway(i)}>
            <span class="dots">{#each swatches(c) as ink}<i style:background={swatch(ink)}></i>{/each}</span>
            {c.name}
          </button>
        {/each}
        <button type="button" aria-pressed={current === -1} onclick={() => useColourway(-1)}>
          <span class="dots original"><i></i><i></i><i></i><i></i></span>
          Original blue
        </button>
      </div>
      <div class="spin">
        <button type="button" class="primary" onclick={randomiseAll}>Randomise all inks</button>
        <button type="button" onclick={spinRandom} disabled={!anyRandom}>Spin random inks</button>
      </div>
      <p class="hint">The shapes stay put; only the inks change.</p>

      <h2 class="sc">Inks</h2>
      {#each meta.parts as [part]}
        <div class="row">
          <span class="cap">{PART_LABEL[part] ?? part}</span>
          <InkPicker {part} label={PART_LABEL[part] ?? part} {meta} bind:value={palette[part]} onchange={changed} />
        </div>
      {/each}

      <h2 class="sc">Shapes</h2>
      <label class="row">
        <span>Seed</span>
        <input type="number" min="1" max="99999" bind:value={seed} onchange={changed}>
      </label>
      <p class="spin"><button type="button" onclick={reroll}>New shapes</button></p>
      <label class="row" title={hint("density")}>
        <span>{label("density")}</span>
        <input type="range" min="0.2" max="2" step="0.1" bind:value={mix.density} oninput={changed}>
        <output>{mix.density}</output>
      </label>
      <p class="hint">Weights: 0 none, 1 the usual amount, 2 about double.</p>
      {#each groups as g}
        <details>
          <summary>{g.title}</summary>
          {#each g.keys as k}
            <label class="row" title={hint(k)}>
              <span>{label(k)}</span>
              <input type="range" min="0" max="3" step="0.25" bind:value={mix[k]} oninput={changed}>
              <output>{mix[k]}</output>
            </label>
          {/each}
        </details>
      {/each}
      <details class="ornaments">
        <summary>Ornaments</summary>
        <p class="hint">Each place on the page picks one kind by these weights; 0 never.
          The crest, flourish, tailpiece and corners appear on the title layout;
          flank takes a crest at its foot, and scrollwork a crest and a tailpiece.</p>
        {#each meta.ornaments as s}
          <h4 title={s.desc}>{s.label}</h4>
          {#each s.kinds as [k, name]}
            <label class="row">
              <span>{name}</span>
              <input type="range" min="0" max="5" step="0.5" bind:value={ornaments[k]} oninput={changed}>
              <output>{ornaments[k]}</output>
            </label>
          {/each}
        {/each}
        <p class="hint"><a href="/ornaments/">See every kind on the ornaments page.</a></p>
      </details>
      <details class="backdrop">
        <summary>Backdrop</summary>
        <div class="choices" role="group" aria-label="What the page is painted over">
          {#each [["light", "Light paper"], ["dark", "Dark page"]] as [b, name]}
            <button type="button" aria-pressed={backdrop === b} onclick={() => { backdrop = b; changed(); }}>{name}</button>
          {/each}
        </div>
        <p class="hint">On a dark page every ink is painted light, as if lit, over a transparent ground; gold stays gold.</p>
      </details>
      <details class="gilt">
        <summary>Gilt</summary>
        <div class="choices" role="group" aria-label="How gold is painted">
          {#each meta.catalog.gilt.modes as m}
            <button type="button" aria-pressed={gilt === m} onclick={() => { gilt = m; changed(); }}>{m}</button>
          {/each}
        </div>
        <p class="hint">Raster computes the gold per pixel; vector builds it in relief from flat strips.
          The looks below apply to raster gold.</p>
        <div class="choices" role="group" aria-label="Gilt look">
          {#each meta.catalog.gilt.looks as lk}
            <button type="button" title={lk.about} aria-pressed={giltenv === lk.name}
              disabled={gilt !== "raster"} onclick={() => setEnv(lk.name)}>{lk.label}</button>
          {/each}
        </div>
        {#each lookKeys as k (k.key)}
          <label class="row" title={k.about}>
            <span>{k.label}</span>
            <input type="range" min={k.min} max={k.max} step={k.step} disabled={gilt !== "raster"}
              value={giltlook[k.key] ?? k.defaults[giltenv]} oninput={(e) => setLook(k, Number(e.currentTarget.value))}>
            <output>{giltlook[k.key] ?? k.defaults[giltenv]}</output>
          </label>
        {/each}
      </details>
      <p class="hint"><a href="/guide/#g-reference">Every setting and value</a> is listed in the guide.</p>
    {/if}
    {#if line}
      <h2 class="sc">LaTeX settings</h2>
      <pre><code>{line}</code></pre>
      <p class="links">
        <button type="button" onclick={() => copy("line")}>{copied === "line" ? "Copied" : "Copy settings"}</button>
        <button type="button" onclick={() => copy("document")}>{copied === "document" ? "Copied" : "Copy complete document"}</button>
      </p>
      <p class="hint">The document compiles with <code>lualatex</code> beside the unzipped
        <a href="/tikzflora.zip" download>tikzflora.zip</a>. Your own text grows its own shapes.</p>
    {/if}
  </div>

  <div class="viewer">
    <div class="sheet paper" bind:this={frame} class:busy class:dark={backdrop === "dark"}
      style={backdrop === "dark" && meta ? `background:${meta.catalog.backdrop.dark}` : undefined}>
      <canvas bind:this={canvas} aria-label="The page's flora"></canvas>
      <div class="bar" class:on={loading || busy} class:loading role="progressbar" aria-label="Growing the page"
        aria-valuemin="0" aria-valuemax="100" aria-valuenow={loading ? undefined : Math.round(progress * 100)}>
        <i style:transform={loading ? undefined : `scaleX(${progress})`}></i>
      </div>
      {#if pages.length}
        <img src={`/bake/text-${variant}.png`} alt="The example page's text">
        {#if lettered}
          <div class="letters" aria-hidden="true"
            style={`background:${letterInk};-webkit-mask-image:url(/bake/letters-${variant}.png);mask-image:url(/bake/letters-${variant}.png)`}></div>
        {/if}
      {/if}
    </div>
    <p class="status" aria-live="polite">{status}</p>
  </div>
</div>

<style>
  /* The controls scroll on their own; the page stays in view. */
  .mixer { display: grid; grid-template-columns: minmax(300px, 410px) minmax(0, 1fr); height: 100%; }
  .controls { overflow-y: auto; overscroll-behavior: contain; padding: 1.5rem 1.5rem 3rem; border-right: 1px solid var(--rule); font-size: 1.05rem; scrollbar-width: thin; scrollbar-color: var(--rule) transparent; }
  h1 { font-size: 2rem; margin: 0 0 .3rem; }
  .note, .hint { color: var(--muted); font-size: .95rem; line-height: 1.45; margin: .2rem 0 .6rem; }
  h2, legend { font-family: var(--body); font-size: 1.08rem; color: var(--rubric); margin: 1.7rem 0 .5rem; padding: 0; }
  legend { margin-top: 0; }
  .row { display: grid; grid-template-columns: 8rem minmax(0, 1fr) 2.4rem; align-items: center; gap: .6rem; min-height: 36px; }
  .row > span { color: var(--muted); }
  output { font-family: var(--mono); font-size: .75rem; text-align: right; }
  input[type="range"] { width: 100%; accent-color: var(--rubric); }
  input[type="number"] { grid-column: 2 / 4; width: 100%; padding: .3rem .45rem; border: 1px solid var(--control); background: transparent; }
  button { border: 1px solid var(--control); background: transparent; padding: .3rem .75rem; cursor: pointer; min-height: 36px; border-radius: 0; }
  button:hover:not(:disabled) { border-color: var(--ink); }
  button:disabled { opacity: .45; cursor: default; }
  button.primary { background: var(--ink); border-color: var(--ink); color: var(--paper); }
  fieldset { border: 0; padding: 0; margin: 1.4rem 0 0; }
  .layouts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .35rem; }
  .layouts label { display: flex; align-items: center; justify-content: center; min-height: 36px; border: 1px solid var(--control); cursor: pointer; }
  .layouts label.on { background: var(--ink); border-color: var(--ink); color: var(--paper); }
  .layouts input { position: absolute; opacity: 0; pointer-events: none; }
  .layouts label:has(input:focus-visible) { outline: 2px solid var(--rubric); outline-offset: 2px; }
  .ways { display: grid; grid-template-columns: 1fr 1fr; gap: .35rem; }
  .ways button { display: flex; align-items: center; gap: .5rem; text-align: left; font-size: .98rem; }
  .ways button[aria-pressed="true"] { border-color: var(--ink); box-shadow: inset 0 0 0 1px var(--ink); }
  .dots { display: inline-flex; flex: none; width: 2.6rem; height: 1rem; overflow: hidden; }
  .dots i { flex: 1; }
  .dots.original i:nth-child(1) { background: oklab(0.40 -0.01 -0.19); }
  .dots.original i:nth-child(2) { background: oklab(0.55 -0.04 -0.18); }
  .dots.original i:nth-child(3) { background: oklab(0.62 -0.08 -0.12); }
  .dots.original i:nth-child(4) { background: oklab(0.75 -0.05 -0.09); }
  .spin { display: flex; flex-wrap: wrap; gap: .45rem; margin: .7rem 0 0; }
  details { border-top: 1px solid var(--rule); padding: .35rem 0; }
  details:last-of-type { border-bottom: 1px solid var(--rule); }
  h4 { font-family: var(--body); font-style: italic; font-size: 1rem; margin: .8rem 0 .2rem; }
  summary { cursor: pointer; font-family: var(--display); font-size: 1.15rem; padding: .3rem 0; }
  pre { white-space: pre-wrap; word-break: break-word; margin: .3rem 0 .6rem; font-size: .7rem; }
  .links { display: flex; flex-wrap: wrap; gap: .45rem; align-items: center; }
  .viewer { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 1.4rem; min-height: 0; overflow: hidden; }
  .sheet { position: relative; height: min(100%, calc(100dvh - var(--bar) - 5rem)); aspect-ratio: 210 / 297; max-width: 100%; box-shadow: 0 1px 2px oklch(30% 0.02 70 / .12), 0 14px 36px -20px oklch(30% 0.02 70 / .4); }
  .sheet canvas, .sheet img { position: absolute; inset: 0; width: 100%; height: 100%; }
  .sheet img { mix-blend-mode: multiply; }
  /* The title lettering: a baked mask filled with its ink. */
  .sheet .letters { position: absolute; inset: 0; mix-blend-mode: multiply; -webkit-mask-size: 100% 100%; mask-size: 100% 100%; }
  /* On a dark page the baked black text and lettering are turned light. */
  .sheet.dark img { filter: invert(1); mix-blend-mode: screen; }
  .sheet.dark .letters { mix-blend-mode: screen; filter: invert(1) hue-rotate(180deg); }
  .choices { display: flex; flex-wrap: wrap; gap: .35rem; margin: .45rem 0; }
  .choices button[aria-pressed="true"] { background: var(--ink); border-color: var(--ink); color: var(--paper); }
  select { grid-column: 2; width: 100%; padding: .3rem .4rem; border: 1px solid var(--control); background: transparent; font: inherit; }
  .chip { width: 1.4rem; height: 1.4rem; justify-self: end; border: 1px solid var(--rule); }
  .sheet.busy canvas { opacity: .45; transition: opacity .3s; }
  /* The grow's progress, along the sheet's foot; it fades once grown. */
  .bar { position: absolute; left: 0; right: 0; bottom: 0; z-index: 1; height: 3px; overflow: hidden; background: oklch(30% 0.02 70 / .08); opacity: 0; transition: opacity .6s .2s; }
  .bar.on { opacity: 1; transition-delay: 0s; }
  .bar i { position: absolute; inset: 0; background: var(--rubric); transform-origin: left; transform: scaleX(0); transition: transform .25s ease-out; }
  .bar.loading i { width: 30%; transform: none; animation: sweep 1.4s ease-in-out infinite; }
  @keyframes sweep { from { translate: -100% 0; } to { translate: 340% 0; } }
  @media (prefers-reduced-motion: reduce) {
    .bar i { transition: none; }
    .bar.loading i { animation: none; width: 100%; opacity: .35; }
  }
  .status { color: var(--muted); font-size: .95rem; font-style: italic; margin: .6rem 0 0; }
  /* Phones: the page scrolls as one, with a small page kept in view. */
  @media (max-width: 860px) {
    .mixer { display: flex; flex-direction: column; height: auto; }
    .viewer { order: -1; position: sticky; top: 0; z-index: 2; height: 36dvh; padding: .5rem; background: var(--paper); border-bottom: 1px solid var(--rule); }
    .sheet { height: calc(36dvh - 2.6rem); }
    .controls { overflow: visible; border-right: 0; padding-inline: 16px; }
    .row { grid-template-columns: 7rem minmax(0, 1fr) 2.4rem; min-height: 44px; }
    button, .layouts label { min-height: 44px; }
  }
</style>
