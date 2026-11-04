<script>
  import Shell from "../lib/Shell.svelte";
  import Guide from "../lib/Guide.svelte";

  const CONTENTS = [
    ["g-install", "Install"], ["g-first", "A first page"], ["g-overleaf", "On Overleaf"],
    ["g-settings", "Settings"], ["g-layouts", "Layouts"], ["g-letters", "Lettering"], ["g-reference", "Every option"], ["g-grow", "Watch it grow"],
    ["g-trouble", "Troubleshooting"], ["credits", "Credits"],
  ];
</script>

<Shell page="guide">
  <article class="guide">
    <!-- The guide's own outer margin grows flora, as the package's pages do. -->
    <figure class="flora" aria-hidden="true"><img src="/img/flora-margin.png" width="268" height="1053" alt=""></figure>
    <header class="lead">
      <p class="sc rubric">From the zip to a page</p>
      <h1>The guide</h1>
    </header>
    <nav class="contents" aria-label="On this page">
      <p class="sc rubric">Contents</p>
      <ol>
        {#each CONTENTS as [id, name]}<li><a href={`#${id}`}>{name}</a></li>{/each}
      </ol>
    </nav>
    <div class="text">
      <Guide />
      <h3 id="credits">Credits</h3>
      <p>tikz-flora would not exist without the r/LaTeX thread
        <a href="https://old.reddit.com/r/LaTeX/comments/1xixznw/how_do_you_make_these_flowers_in_latex/">How do you make these flowers in LaTeX?</a>,
        whose photographed page is the reference it is measured against,
        and Kevin Raymond's
        <a href="https://github.com/kevinraymond/florilegium">florilegium</a>
        (MIT), whose grown margins, animation and visitors it follows.</p>
      <p>Ink colours: Pilot iroshizuku ramps measured by
        <a href="https://madoromi.moonwit.ch/#palettes/colours">madoromi</a>.
        Growth after Wong, Zongker and Salesin,
        <a href="https://grail.cs.washington.edu/projects/ornament/ornament.pdf">Computer-Generated Floral Ornament</a>
        (SIGGRAPH 1998). Example text from Vitruvius (tr. Morgan, 1914)
        and Asa Gray (1887), via Project Gutenberg. The mixer runs the
        package's Lua with <a href="https://github.com/ceifa/wasmoon">wasmoon</a>
        and draws it with <a href="https://mozilla.github.io/pdf.js/">pdf.js</a>.</p>
      <p>Written with Claude Code. MIT licence. Source on
        <a href="https://github.com/wn-mitch/tikz-flora">GitHub</a>.</p>
    </div>
  </article>
</Shell>

<style>
  /* [flora | text | contents]: the flora fills the outer margin and the
     contents stay beside the text as it scrolls. */
  .guide {
    display: grid; grid-template-columns: [flora] minmax(0, 13rem) [text] minmax(0, var(--measure)) [contents] minmax(0, 12rem);
    column-gap: var(--gutter); justify-content: center; padding: 0 var(--side);
  }
  .lead { grid-column: text; grid-row: 1; padding-top: clamp(2rem, 6vh, 4rem); margin-bottom: 2.2rem; }
  .lead p { margin: 0 0 .2rem; }
  h1 { font-size: clamp(2.6rem, 5vw, 3.8rem); margin: 0; }
  .text { grid-column: text; grid-row: 2; min-width: 0; }
  .flora { grid-column: flora; grid-row: 1 / 3; margin: 0; }
  .flora img { position: sticky; top: 1.5rem; display: block; width: 100%; height: auto; max-height: calc(100svh - 3rem); object-fit: contain; object-position: right top; mix-blend-mode: multiply; }
  .contents { grid-column: contents; grid-row: 2; align-self: start; position: sticky; top: 1.5rem; font-size: 1.02rem; }
  .contents p { margin: 0 0 .3rem; }
  .contents ol { list-style: none; margin: 0; padding: 0; }
  .contents li { padding: .12rem 0; }
  .contents a { text-decoration: none; color: var(--muted); }
  .contents a:hover { color: var(--rubric); }
  #credits { margin-top: 3rem; }
  @media (max-width: 75rem) {
    .guide { grid-template-columns: [text] minmax(0, var(--measure)) [contents] minmax(0, 12rem); }
    .flora { display: none; }
  }
  @media (max-width: 52rem) {
    .guide { grid-template-columns: [text contents] minmax(0, 1fr); }
    .contents { grid-row: 2; position: static; margin-bottom: 2rem; }
    .contents ol { display: flex; flex-wrap: wrap; gap: 0 1rem; }
    .text { grid-row: 3; }
  }
</style>
