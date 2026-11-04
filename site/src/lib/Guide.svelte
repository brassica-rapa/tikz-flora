<script>
  // Code samples live here: braces in markup would be read as Svelte.
  const minimal = String.raw`\documentclass{article}
% The flora fills the margins the page has: give it about 5 cm.
\usepackage[left=5.5cm,right=2cm,top=4cm,bottom=3.5cm]{geometry}
\usepackage{tikzflora}
\florasetup{seed=7}

\begin{document}
\section{A first garden}
Some text.
\end{document}`;

  const settings = String.raw`% For the rest of the document, from this page on:
\florasetup{layout=split, seed=3, visitors=0.5,
  mix={lily=2, umbel=0, gyps=1.5},
  palette={hero=murasaki-shikibu, blooms=warm, leaves=teal}}

% For one page only (the page this lands on):
\florathispage{layout=surround}`;

  const title = String.raw`\newgeometry{left=3.2cm,right=3.2cm,top=5cm,bottom=4cm}
\thispagestyle{empty}
\florathispage{layout=title}
\begin{floratitle}
\centering {\Huge\scshape My Title\par}
\end{floratitle}
\clearpage
\restoregeometry`;

  const letters = String.raw`{\fontsize{46}{52}\selectfont\floraletters{FLORA'S}\par}
{\fontsize{30}{36}\selectfont
  \floraletters[style=engraved, arch=24]{DICTIONARY}\par}`;

  const texmf = String.raw`kpsewhich -var-value TEXMFHOME
# then copy tikzflora.sty, tikzflora-boot.lua and lua/ into
#   <TEXMFHOME>/tex/lualatex/tikzflora/`;

  // Every setting, layout and value, from the package's own Lua
  // (lua/flora/catalog.lua, baked to /bake/catalog.json by just site-bake).
  import { onMount } from "svelte";
  let cat = $state(null);
  onMount(async () => {
    try { cat = await fetch("/bake/catalog.json").then((r) => r.json()); } catch { cat = null; }
  });
  const ARCH = (a) => `${a[0]} to ${a[1]} degrees`;
</script>

  <h3 id="g-install">1. Get LuaLaTeX</h3>
  <p>
    tikz-flora needs LuaLaTeX, which comes with every full TeX
    distribution: <a href="https://tug.org/texlive/">TeX Live</a> 2023 or
    later, <a href="https://miktex.org/">MiKTeX</a>, or
    <a href="https://yihui.org/tinytex/">TinyTeX</a>. Check that
    <code>lualatex --version</code> answers. The example also needs the
    <code>lipsum</code> package (<code>tlmgr install lipsum</code> on
    TinyTeX).
  </p>

  <h3>2. Get the package</h3>
  <p>
    <a href="/tikzflora.zip" download>Download tikzflora.zip</a> and unzip
    it into a folder of its own. It holds <code>tikzflora.sty</code>, <code>tikzflora-boot.lua</code>,
    the generator in <code>lua/flora/</code>, a worked example
    <code>example.tex</code>, and a <code>latexmkrc</code> that selects
    LuaLaTeX.
  </p>
  <p>
    Put your document next to <code>tikzflora.sty</code>, or copy the
    <code>.sty</code>, the boot file and <code>lua/</code> next to your
    document. To use it in every document, copy them into your TeX tree:
  </p>
  <pre><code>{texmf}</code></pre>

  <h3 id="g-first">3. A first page</h3>
  <pre><code>{minimal}</code></pre>
  <p>
    Compile with <code>lualatex</code>, or with <code>latexmk</code>, which
    the included <code>latexmkrc</code> points at LuaLaTeX. pdfLaTeX and
    XeLaTeX stop with "tikzflora needs LuaLaTeX". Each page takes a second
    or two to grow.
  </p>

  <h3 id="g-overleaf">On Overleaf</h3>
  <ol>
    <li>Choose New Project, then Upload Project, and pick <code>tikzflora.zip</code>.</li>
    <li>The <code>latexmkrc</code> in the zip selects LuaLaTeX. If your project lacks it, open Menu and set Compiler to LuaLaTeX.</li>
    <li>The zip holds two documents. If Overleaf opens <code>titles.tex</code>, set Menu, Main document to <code>example.tex</code>.</li>
    <li>Recompile. <code>example.tex</code> shows every setting with a comment at each.</li>
    <li>To add flora to a project you already have, upload <code>tikzflora.sty</code>, <code>tikzflora-boot.lua</code> and the <code>lua</code> folder to its top level, beside the main document.</li>
  </ol>

  <h3 id="g-settings">4. Settings</h3>
  <p>
    <code>\florasetup</code> sets keys for the rest of the document,
    starting with the page it is on. <code>\florathispage</code> sets them
    for one page. A wrong key or value stops the compile with a message
    naming it.
  </p>
  <pre><code>{settings}</code></pre>
  <div class="table">
    <table>
      <thead><tr><th>Key</th><th>Values</th><th>Effect</th></tr></thead>
      <tbody>
        {#each cat?.settings ?? [] as st}<tr><td><code>{st.key}</code></td><td>{st.values}</td><td>{st.about}</td></tr>{/each}
      </tbody>
    </table>
  </div>
  <p>Visitors are off unless you give them weight. <a href="#g-reference">Every option</a>
    below lists each mix kind, ornament, ink and gilt key.</p>
  <p>
    Palette values are <code>look</code> (the original blue gradients), an
    ink group (warm, violet, gold, earth, green, teal, blue-grey, blue), one
    Pilot iroshizuku ink by name, such as <code>momiji</code> or
    <code>sui-gyoku</code>, or <code>random</code> for one ink picked per
    page. A non-blue ink also repaints that part's rims, grain and contours,
    so with every part set only a few pen lines stay navy. With
    <code>random</code>, <code>spin=N</code> picks again and changes only
    the colours. The <a href="/mixer/">mixer</a> shows every ink as a
    swatch.
  </p>

  <h3 id="g-layouts">5. Layouts</h3>
  <dl>
    {#each cat?.layouts ?? [] as l}<dt><code>{l.name}</code></dt><dd>{l.about}</dd>{/each}
  </dl>
  <p>A title page:</p>
  <pre><code>{title}</code></pre>

  <p>
    The last four are for title pages, after engraved and hand-coloured
    flower books. Each frames the lines in <code>floratitle</code>. The
    oval of <code>wreath</code> and <code>scrollwork</code> spans the
    page and keeps to the room between the title and the nearest lines
    above and below it. <code>titles.tex</code> in the zip has a page in
    each.
  </p>

  <h3 id="g-letters">6. Lettering</h3>
  <p>
    <code>\floraletters</code> draws a line of display capitals as an
    engraver lettered them, from the font's own outlines, in the font and
    size in force:
  </p>
  <pre><code>{letters}</code></pre>
  <dl>
    <dt><code>style</code></dt><dd><code>outline</code>, the letter drawn round; <code>shaded</code>, outlined with a hatched shadow (the default); or <code>engraved</code>, the face ruled with fine lines over a solid shadow.</dd>
    <dt><code>arch</code></dt><dd>The degrees the baseline bends through: positive arches the middle up, negative sags it.</dd>
    <dt><code>ink</code></dt><dd>An iroshizuku ink by name for the line work, or <code>black</code> (the default).</dd>
  </dl>
  <p>
    It needs an OpenType or TrueType font, as LuaLaTeX's default and any
    <code>fontspec</code> font are. The flora keeps clear of it as it does
    of text.
  </p>

  <h3 id="g-reference">7. Every option</h3>
  <p>
    Read from the package itself, so it lists exactly what it accepts. The
    <a href="/mixer/">mixer</a> has a control for each.
  </p>
  {#if cat}
    <h4>Mix: <code>mix=&#123;kind=weight, …&#125;</code></h4>
    {#each cat.mix as g}
      <p class="sub">{g.group}</p>
      <dl class="ref">
        {#each g.kinds as k}<dt><code>{k.key}</code> <span class="muted">{k.label}, default {k.default}</span></dt><dd>{k.about}</dd>{/each}
      </dl>
    {/each}
    <h4>Ornaments: <code>ornaments=&#123;kind=weight, …&#125;</code></h4>
    {#each cat.ornaments as o}
      <p class="sub">{o.label}</p>
      <p class="list">{o.about} {#each o.kinds as k, i}<code>{k.key}</code> ({k.label}, {k.default}){i < o.kinds.length - 1 ? ", " : "."} {/each}</p>
    {/each}
    <h4>Palette: <code>palette=&#123;part=ink, …&#125;</code></h4>
    <p class="list">Parts, with their defaults: {#each cat.parts as p, i}<code>{p.key}</code> ({p.default}){i < cat.parts.length - 1 ? ", " : "."} {/each}</p>
    <p class="list">Each takes <code>look</code>, <code>random</code>, an ink group or one ink:</p>
    <dl class="ref">
      {#each cat.ink_groups as g}<dt><code>{g.name}</code></dt><dd>{g.inks.join(", ")}</dd>{/each}
    </dl>
    <h4>Colourways: <code>colourway=…</code></h4>
    <dl class="ref">
      {#each cat.colourways as c}<dt><code>{c.name}</code></dt><dd>{Object.keys(c.inks).length ? Object.entries(c.inks).map(([p, ink]) => `${p} ${ink}`).join(", ") : "the package's own blue look"}</dd>{/each}
    </dl>
    <h4>Gilt: <code>gilt</code>, <code>giltdpi</code>, <code>giltenv</code>, <code>giltlook=&#123;key=value, …&#125;</code></h4>
    <p class="list"><code>gilt</code>: {cat.gilt.modes.join(" or ")} (default {cat.gilt.default}). <code>giltdpi</code>: {cat.gilt.dpi[0]} to {cat.gilt.dpi[1]} (default {cat.gilt.dpi[2]}). <code>giltenv</code>:
      {#each cat.gilt.looks as lk, i}<code>{lk.name}</code> ({lk.about}){i < cat.gilt.looks.length - 1 ? "; " : "."} {/each}</p>
    <div class="table">
      <table>
        <thead><tr><th>giltlook key</th><th>Range</th><th>Default</th><th>Effect</th></tr></thead>
        <tbody>
          {#each cat.gilt.keys as k}<tr><td><code>{k.key}</code></td><td>{k.min} to {k.max}</td>
            <td>{k.look ? `${k.defaults[k.look]} (${k.look} only)` : `${k.defaults.studio} studio, ${k.defaults.mirror} mirror`}</td><td>{k.about}</td></tr>{/each}
        </tbody>
      </table>
    </div>
    <h4>Lettering: <code>\floraletters[style=…, arch=…, ink=…]</code></h4>
    <dl class="ref">
      {#each cat.letters.styles as st}<dt><code>style={st.name}</code></dt><dd>{st.about}</dd>{/each}
      <dt><code>arch</code></dt><dd>{ARCH(cat.letters.arch)}: positive arches the middle up, negative sags it; 0 (the default) keeps it straight.</dd>
      <dt><code>ink</code></dt><dd><code>black</code> (the default) or any ink above.</dd>
    </dl>
  {:else}
    <p class="muted">Loading the list…</p>
  {/if}

  <h3 id="g-grow">Watch it grow</h3>
  <p>
    The repository's <code>just grow NAME SEED PAGE</code> renders a page
    of any document in <code>tex/</code> as it grows and writes an MP4 and
    a GIF. It needs ffmpeg, poppler and ImageMagick. The animation on this
    page is <code>just grow lorem 3 3</code>.
  </p>

  <h3 id="g-trouble">Troubleshooting</h3>
  <dl>
    <dt>"tikzflora needs LuaLaTeX"</dt>
    <dd>Compile with <code>lualatex</code>. On Overleaf, set Menu, Compiler to LuaLaTeX.</dd>
    <dt>"module 'flora.init' not found"</dt>
    <dd>TeX found <code>tikzflora.sty</code> but not the <code>lua/</code> folder. Keep <code>lua/</code> beside the <code>.sty</code>, or set <code>FLORA_LUA</code> to its path.</dd>
    <dt>The contents page is empty</dt>
    <dd>Compile twice, or use <code>latexmk</code>.</dd>
    <dt>A long document is slow to compile</dt>
    <dd>Growing a page's flora takes a few seconds, so the first compile is slow. Each page's flora is then kept in a folder <code>&lt;jobname&gt;-flora</code> beside the PDF, and later compiles reuse every page whose text did not move, so LaTeX's second and third runs cost almost nothing. <code>\florasetup&#123;cache=false&#125;</code> keeps nothing. While you write, turn the flora off with <code>\floraoff</code> and back on with <code>\floraon</code>; put <code>\floraoff</code> in the preamble to draft without any.</dd>
    <dt>The flora is cramped</dt>
    <dd>It fills the margins it is given. Widen them with <code>geometry</code> (about 5 cm for a side margin, or 3 cm all round for <code>surround</code>), or lower <code>density</code>.</dd>
  </dl>

<style>
  .table { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; font-size: 1.02rem; line-height: 1.4; margin: .6rem 0 1.2rem; }
  th, td { text-align: left; padding: .4rem .6rem; border-bottom: 1px solid var(--rule); vertical-align: top; }
  th { font-weight: 400; color: var(--rubric); font-variant-caps: all-small-caps; letter-spacing: .07em; }
  dt { margin-top: .6rem; }
  dd { margin: .1rem 0 0 1.2rem; color: var(--muted); }
  ol { padding-left: 1.3rem; }
  h3 { font-size: 1.6rem; margin: 3rem 0 .7rem; }
  h3:first-child { margin-top: 0; }
  h4 { font-family: var(--body); font-size: 1.15rem; margin: 2rem 0 .4rem; }
  .sub { font-variant-caps: all-small-caps; letter-spacing: .06em; color: var(--rubric); margin: 1rem 0 .2rem; }
  .list { line-height: 1.6; }
  .muted { color: var(--muted); }
  /* Phones: each setting stacks as key, values, effect. */
  @media (max-width: 600px) {
    thead { display: none; }
    tr, td { display: block; }
    tr { padding: .5rem 0; border-bottom: 1px solid var(--rule); }
    td { border: 0; padding: .1rem 0; }
    td:nth-child(2) { color: var(--muted); }
  }
</style>
