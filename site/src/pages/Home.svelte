<script>
  import Shell from "../lib/Shell.svelte";
  import Ornament from "../lib/Ornament.svelte";
  import Lightbox from "../lib/Lightbox.svelte";
  import COLOURWAYS from "../lib/colourways.json";

  // The example document's pages, with what each shows.
  const pages = [
    [1, "Flanked title", "layout=flank"],
    [2, "Contents wreath", "layout=surround"],
    [3, "Outer margin, into a gap", "layout=split"],
    [4, "A new mix: lilies, umbels, birds", "mix={…}, palette={leaves=green}"],
    [5, "Outer margin, filler text", "layout=split"],
    [6, "Both margins, random inks", "layout=centered, palette={…=random}"],
    [7, "A short last page", "density=0.6"],
  ];
  const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII"];
  // The plate shows the four seasons, each with its baked page.
  const SEASONS = COLOURWAYS.map((c, i) => ({ ...c, i })).filter((c) => c.season);
  // The title pages of tex/titles.tex, one per title layout.
  const TITLES = [
    ["flank", "Flank", "Plants up both sides, meeting round a crest at the foot."],
    ["wreath", "Wreath", "An open oval garland, tied at its foot."],
    ["bouquet", "Bouquet", "A tied bouquet, the title on ribbons through it."],
    ["scrollwork", "Scrollwork", "A gilt scroll frame with the flora twined over it."],
  ];
  // The rest of the site, as a contents list.
  const doors = [
    ["/mixer/", "The mixer", "Choose plants, inks and ornaments; the package grows the page in your browser and writes the settings."],
    ["/ornaments/", "Ornaments", "Every gilt piece by its place on the page, from cartouches to title corners."],
    ["/guide/", "The guide", "Install, compile a first page, and every key the package takes."],
  ];
  // Each picture on the page, as the viewer (Lightbox.svelte) shows it: its
  // image, the large copy site-bake makes of it, and its words. Clicking a
  // picture opens its group there.
  const view = (name, alt, caption) => ({ small: `/img/${name}.jpg`, large: `/img/large/${name}.jpg`, alt, caption });
  const FRONT = [view("page-1", "The title page of the example document, with a painted plant up each side meeting at the foot round a gilt crest", "The example document's title page")];
  const SEASON_VIEWS = SEASONS.map((c) => view(`colourway-${c.i}`, `The same page of text with its margin grown in ${c.name.toLowerCase()} inks`, `${c.name}: colourway=${c.key}`));
  const TITLE_VIEWS = TITLES.map(([key, name, what], i) => view(`title-${i + 1}`, `A title page in the ${name.toLowerCase()} layout: ${what.toLowerCase()}`, `${name}: layout=${key}`));
  const PAGE_VIEWS = pages.map(([p, what, how]) => view(`page-${p}`, `Page ${p} of the example document: ${what.toLowerCase()}`, `${what}: ${how}`));
  let viewer;
  // A plain click opens the viewer; a modified one follows the link to the
  // large image, as a link does.
  function enlarge(e, list, i) {
    if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    e.preventDefault();
    viewer.open(list, i);
  }
  const NPM = "https://www.npmjs.com/package/@alpaca-software/web-flora";
  const REPO = "https://github.com/wn-mitch/flora";
</script>

<Shell page="home">
  <section class="opening">
    <figure class="frontis rise">
      <a class="enlarge" href={FRONT[0].large} onclick={(e) => enlarge(e, FRONT, 0)}>
        <img class="paper" src={FRONT[0].small} width="910" height="1287" alt={FRONT[0].alt}></a>
    </figure>
    <div class="titling rise late">
      <p class="sc rubric">A package for LuaLaTeX</p>
      <h1>Watercolour margins that grow</h1>
      <p class="lede">Each page grows its own plant around its text, painted in
        fountain-pen inks and finished with gilt. Pick the plants and inks;
        the package does the rest when the document compiles.</p>
      <p class="actions">
        <a class="button primary" href="/tikzflora.zip" download>Download the package</a>
        <a class="button" href="/mixer/">Open the mixer</a>
      </p>
      <p class="also">Growing a web page instead? <a href="#engine">web-flora</a>
        is the same garden as a TypeScript package.</p>
    </div>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={1} /></div>

  <section class="book chapter" aria-labelledby="ways">
    <header class="wide lead">
      <p class="sc rubric">Plate I</p>
      <h2 id="ways">One page through the seasons</h2>
    </header>
    <div class="wide ways">
      {#each SEASONS as c, i}
        <figure>
          <a class="enlarge" href={SEASON_VIEWS[i].large} onclick={(e) => enlarge(e, SEASON_VIEWS, i)}>
            <img class="paper" src={SEASON_VIEWS[i].small} width="910" height="1287" loading="lazy" alt={SEASON_VIEWS[i].alt}></a>
          <figcaption class="caption">
            <span class="line"><span class="sc">{c.name}</span> <a href={`/mixer/?way=${c.key}`}>Use these inks</a></span>
            <code>colourway={c.key}</code>
          </figcaption>
        </figure>
      {/each}
    </div>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={2} /></div>

  <section class="book chapter" aria-labelledby="titles">
    <header class="wide lead">
      <p class="sc rubric">Plate II</p>
      <h2 id="titles">Four title pages</h2>
      <p class="caption">After engraved flower books of the nineteenth century,
        lettered with <code>\floraletters</code>.</p>
    </header>
    <div class="wide titles">
      {#each TITLES as [key, name, what], i}
        <figure>
          <a class="enlarge" href={TITLE_VIEWS[i].large} onclick={(e) => enlarge(e, TITLE_VIEWS, i)}>
            <img class="paper" src={TITLE_VIEWS[i].small} width="910" height="1287" loading="lazy" alt={TITLE_VIEWS[i].alt}></a>
          <figcaption class="caption">
            <span class="line"><span class="sc">{name}</span> <a href={`/mixer/?layout=${key}`}>Try it</a></span>
            <code>layout={key}</code>
          </figcaption>
        </figure>
      {/each}
    </div>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={3} /></div>

  <section class="book chapter" aria-labelledby="grow">
    <header class="wide lead">
      <p class="sc rubric">Plate III</p>
      <h2 id="grow">Watch it grow</h2>
    </header>
    <video class="paper growth" src="/media/grow.mp4" poster="/img/page-3.jpg" controls muted playsinline preload="none"
      width="910" height="1287" aria-label="Page 3 of the example as its margin flora grows from the root">
      <a href="/media/grow.gif">The animation as a GIF</a>
    </video>
    <div class="note side">
      <p>The plant starts at its root and grows along the stems. Then the
        leaves unfurl, the blooms open and the gilt arrives.</p>
      <p class="caption">The repository's <code>just grow</code> renders any page
        of a document this way.</p>
    </div>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={4} /></div>

  <section class="chapter example" aria-labelledby="example">
    <header class="book"><div class="wide lead">
      <p class="sc rubric">Plate IV</p>
      <h2 id="example">The example document</h2>
      <p class="caption">Seven pages of one document, each with the setting that shaped it.</p>
    </div></header>
    <ol class="pages" data-flora-avoid>
      {#each pages as [p, what, how], i}
        <li>
          <a class="enlarge" href={PAGE_VIEWS[i].large} onclick={(e) => enlarge(e, PAGE_VIEWS, i)}>
            <img class="paper" src={PAGE_VIEWS[i].small} width="910" height="1287" loading="lazy" alt={PAGE_VIEWS[i].alt}></a>
          <p class="caption"><span class="sc">{ROMAN[i]}.</span> {what}<br><code>{how}</code></p>
        </li>
      {/each}
    </ol>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={5} /></div>

  <section class="book chapter" aria-labelledby="engine">
    <header class="wide lead">
      <p class="sc rubric">Plate V</p>
      <h2 id="engine">The same garden on the web</h2>
    </header>
    <div class="engine">
      <p>The margins of this page are grown by web-flora, the package's
        engine in TypeScript. Given the same seed it grows the same plant as
        the Lua inside LuaLaTeX, and draws it with WebGL2, or a 2D canvas
        where WebGL2 is missing.</p>
      <table class="packages">
        <caption class="sr">The two packages</caption>
        <thead><tr><td></td><th scope="col">tikz-flora</th><th scope="col">web-flora</th></tr></thead>
        <tbody>
          <tr><th scope="row">For</th><td>LuaLaTeX documents</td><td>Web pages</td></tr>
          <tr><th scope="row">Written in</th><td>Lua, run by LuaLaTeX</td><td>TypeScript, run in the browser</td></tr>
          <tr><th scope="row">Paints</th><td>The PDF, as it compiles</td><td>A canvas, with WebGL2 or 2D</td></tr>
          <tr><th scope="row">Get it</th>
            <td><a href="/tikzflora.zip" download>tikzflora.zip</a></td>
            <td><a href={NPM}>@alpaca-software/web-flora</a> on npm; source on <a href={REPO}>GitHub</a></td></tr>
        </tbody>
      </table>
      <pre><code>{`npm install @alpaca-software/web-flora`}</code></pre>
      <pre><code>{`import { compose, Painter } from "@alpaca-software/web-flora/engine";
import { toDisplayList, WebGLRenderer } from "@alpaca-software/web-flora";

// A margin 160 x 900 pt, its column of text from x = 130.
const text = { x0: 130, y0: 24, x1: 160, y1: 876 };
const spec = { width: 160, height: 900, seed: 7, text, lines: [text] };
const pt = new Painter({ width: 160, height: 900 });
compose.plant(spec, pt);

// Onto a 160 x 900 canvas.
const canvas = document.querySelector("canvas");
const list = toDisplayList(pt.scene());
new WebGLRenderer(canvas).draw(list, { scale: 1 });`}</code></pre>
    </div>
    <div class="note side">
      <p><code>compose.plant</code> grows one plant into a margin;
        <code>compose.page</code> grows a whole page in any of the package's
        layouts, and <code>ornaments.draw</code> sets a single ornament, as
        between these plates.</p>
      <p class="caption">It ships as JavaScript with type declarations, for
        plain Node or any bundler. MIT licence, as the package is.</p>
    </div>
  </section>

  <div class="divider"><Ornament slot="flourish" seed={6} /></div>

  <section class="book chapter" aria-labelledby="contents">
    <header class="lead">
      <p class="sc rubric">Contents</p>
      <h2 id="contents" class="sr">The rest of the site</h2>
    </header>
    <ol class="contents">
      {#each doors as [href, name, what], i}
        <li>
          <a {href}><span class="name">{name}</span><span class="leader" aria-hidden="true"></span><span class="sc rubric num">{ROMAN[i]}</span></a>
          <p class="caption">{what}</p>
        </li>
      {/each}
    </ol>
  </section>
  <Lightbox bind:this={viewer} />
</Shell>

<style>
  /* The opening is a spread: the title page as frontispiece, the titling
     facing it. */
  .opening {
    display: grid; grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); gap: clamp(2rem, 6vw, 5.5rem); align-items: center;
    max-width: calc(var(--measure) + var(--gutter) + var(--margin) + 2 * var(--side));
    margin: 0 auto; padding: clamp(2rem, 6vh, 4.5rem) var(--side) 2rem;
  }
  .frontis { margin: 0; }
  .frontis img { display: block; width: 100%; height: auto; max-height: 78svh; object-fit: contain; object-position: left; box-shadow: 0 1px 2px oklch(30% 0.02 70 / .12), 0 12px 32px -18px oklch(30% 0.02 70 / .35); }
  .titling { max-width: 30rem; }
  h1 { font-size: clamp(2.6rem, 5.4vw, 4.4rem); line-height: 1.02; margin: .3rem 0 1.2rem; }
  .lede { font-size: 1.3rem; line-height: 1.5; }
  .actions { display: flex; flex-wrap: wrap; gap: .6rem; margin-top: 1.6rem; }
  .chapter { padding-top: clamp(4rem, 10vh, 7rem); }
  /* A flourish of the package's own between the plates, set in the gap a
     chapter would otherwise open with. */
  .divider { max-width: calc(var(--measure) + var(--gutter) + var(--margin) + 2 * var(--side)); margin: 0 auto; padding: clamp(2.5rem, 7vh, 5rem) var(--side) 0; }
  .divider + .chapter { padding-top: clamp(2rem, 5vh, 3.5rem); }
  .lead { margin-bottom: 1.6rem; }
  .lead p.sc { margin: 0 0 .2rem; }
  .lead h2 { margin: 0; }
  .lead .caption { margin: .5rem 0 0; }
  .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); }
  figure { margin: 0; }
  .enlarge { display: block; cursor: zoom-in; }
  .enlarge:focus-visible { outline: 2px solid var(--rubric); outline-offset: 3px; }
  .ways, .titles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: clamp(1rem, 2vw, 1.6rem); }
  .ways code, .titles code { font-size: .68rem; }
  .ways img, .titles img, .pages img { display: block; width: 100%; height: auto; box-shadow: 0 0 0 1px var(--rule); }
  .ways figcaption, .titles figcaption { margin-top: .6rem; }
  .ways .line, .titles .line { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 0 .6rem; }
  .engine { grid-column: text; min-width: 0; }
  .engine pre { font-size: .76rem; }
  .packages { width: 100%; border-collapse: collapse; margin: 1.2rem 0 1.4rem; font-size: .98rem; }
  .packages th, .packages td { text-align: left; vertical-align: top; padding: .45rem .8rem .45rem 0; border-bottom: 1px solid var(--rule); }
  .packages thead th { font-family: var(--display); font-weight: normal; font-size: 1.15rem; }
  .packages tbody th { font-weight: normal; color: var(--muted); white-space: nowrap; }
  .also { color: var(--muted); font-size: .98rem; margin: 1rem 0 0; }
  .growth { grid-column: text; width: 100%; height: auto; max-height: 82svh; object-fit: contain; display: block; box-shadow: 0 0 0 1px var(--rule); }
  .side { align-self: end; }
  .side p:first-child { font-size: 1.15rem; }
  /* The strip starts on the text edge; snapping keeps that inset. */
  .pages {
    --inset: max(var(--side), calc((100vw - var(--measure) - var(--gutter) - var(--margin)) / 2));
    list-style: none; margin: 0; display: flex; gap: clamp(1rem, 2vw, 1.6rem); overflow-x: auto;
    scroll-snap-type: x proximity; scroll-padding-inline: var(--inset);
    padding: .2rem var(--inset) 1rem;
    scrollbar-width: thin; scrollbar-color: var(--rule) transparent;
  }
  .pages li { flex: none; width: clamp(200px, 22vw, 290px); scroll-snap-align: start; }
  .pages .caption { margin: .55rem 0 0; }
  .pages code { font-size: .7rem; }
  .contents { list-style: none; padding: 0; margin: 0; }
  .contents li { margin-bottom: 1.3rem; }
  .contents a { display: flex; align-items: baseline; gap: .5rem; text-decoration: none; font-family: var(--display); font-size: 1.6rem; }
  .contents .leader { flex: 1; border-bottom: 1px dotted var(--control); transform: translateY(-.3em); }
  .contents .num { font-family: var(--body); font-size: 1.1rem; }
  .contents a:hover .name { color: var(--rubric); }
  .contents .caption { margin: .15rem 0 0; max-width: 32rem; }
  @media (max-width: 60rem) {
    .ways, .titles { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .opening { grid-template-columns: minmax(0, 1fr); }
    .frontis { order: 1; }
    .frontis img { max-height: 70svh; object-position: center; }
    .side { margin-top: 1rem; }
  }
  @media (max-width: 40rem) {
    .ways, .titles { grid-template-columns: minmax(0, 1fr); gap: 2rem; }
    .pages li { width: 68vw; }
  }
</style>
