<script>
  // Every page's running head and colophon. `page` names the current page
  // for the nav; `tool` gives the page the screen below the head, inset
  // on wide screens to leave side margins. Every page grows a plant down
  // each side margin wide enough for one (margins.js), loaded once the
  // page is up; the gear in the corner opens its dials (dials.js), loaded
  // on first press.
  import { onMount } from "svelte";
  import Ornament from "./Ornament.svelte";
  let { page, tool = false, children } = $props();
  let garden = $state(null);
  onMount(() => {
    let gone = false;
    import("./margins.js").then(({ startMargins }) => {
      if (!gone) garden = startMargins();
    }, (e) => console.error(e));
    return () => {
      gone = true;
      garden?.stop();
      import("./dials.js").then((d) => d.closeDials(), () => {});
    };
  });
  function dials() {
    import("./dials.js").then((d) => d.toggleDials(garden), (e) => console.error(e));
  }
  const NAV = [["mixer", "/mixer/", "Mixer"], ["ornaments", "/ornaments/", "Ornaments"], ["guide", "/guide/", "Guide"]];
</script>

<header class="head" class:tool>
  <a class="title" href="/" aria-current={page === "home" ? "page" : undefined}>tikz-flora</a>
  <nav aria-label="Pages">
    {#each NAV as [k, href, label]}
      <a class="sc" {href} aria-current={page === k ? "page" : undefined}>{label}</a>
    {/each}
    <a class="sc get" href="/tikzflora.zip" download>Download</a>
  </nav>
</header>

<main class:tool>
  {@render children()}
</main>

{#if garden}
  <button class="gear" type="button" data-flora-ui onclick={dials} aria-label="Tune the margin garden" title="Tune the margin garden">
    <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
      <path fill="currentColor" d="M19.4 13a7.6 7.6 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7.4 7.4 0 0 0-1.7-1L15 3.2h-4l-.4 2.7a7.4 7.4 0 0 0-1.7 1l-2.5-1-2 3.5L6.6 11a7.6 7.6 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7.4 7.4 0 0 0 1.7 1l.4 2.7h4l.4-2.7a7.4 7.4 0 0 0 1.7-1l2.5 1 2-3.5zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z" transform="translate(-1 0)"/>
    </svg>
  </button>
{/if}

{#if !tool}
  <footer class="colophon">
    <div class="tailpiece"><Ornament slot="tailpiece" seed={97} width={170} aspect={1.6} /></div>
    <p>Set in IM Fell English and EB Garamond. Every flower, ink wash and
      ornament on these pages is drawn by the package: the plates by its
      Lua, the margins and the ornaments between them by flora, its
      TypeScript engine.</p>
    <p class="sc">
      <a href="/guide/#credits">Credits</a> · MIT licence ·
      <a href="https://github.com/wn-mitch/tikz-flora">Source on GitHub</a>
    </p>
  </footer>
{/if}

<style>
  .head {
    display: flex; align-items: baseline; justify-content: space-between; gap: 1rem;
    max-width: calc(var(--measure) + var(--gutter) + var(--margin) + 2 * var(--side));
    margin: 0 auto; padding: 1rem var(--side) 0; min-height: var(--bar);
  }
  .head.tool { max-width: none; margin-inline: var(--tool-inset); padding: 0 1.4rem; align-items: center; border-bottom: 1px solid var(--rule); height: var(--bar); }
  .title { font-family: var(--display); font-size: 1.35rem; text-decoration: none; }
  nav { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: .2rem 1.2rem; font-size: 1.08rem; }
  nav a { text-decoration: none; color: var(--muted); }
  nav a:hover, nav a[aria-current="page"] { color: var(--rubric); }
  nav a[aria-current="page"] { text-decoration: underline; text-decoration-color: var(--rubric); text-underline-offset: .3em; }
  main.tool { height: calc(100dvh - var(--bar)); margin-inline: var(--tool-inset); }
  /* A tool page keeps a margin each side for the garden on wide screens,
     leaving the tool about 1100 px; narrower screens give it the width. */
  :global(:root) { --tool-inset: 0px; }
  @media (min-width: 1200px) { :global(:root) { --tool-inset: clamp(140px, (100vw - 1100px) / 2, 320px); } }
  .colophon { max-width: var(--measure); margin: 0 auto; padding: 4rem var(--side) 3rem; text-align: center; font-size: .98rem; color: var(--muted); }
  .colophon p { margin: 0 0 .5rem; }
  .tailpiece { margin: 0 auto 1.2rem; }
  .gear {
    position: fixed; right: 14px; bottom: 14px; z-index: 5; width: 36px; height: 36px; padding: 0;
    display: grid; place-items: center; border: 1px solid var(--rule); border-radius: 50%;
    background: var(--paper); color: var(--muted); cursor: pointer; opacity: .7;
  }
  .gear:hover, .gear:focus-visible { opacity: 1; color: var(--rubric); }
  @media (max-width: 40rem) {
    .gear { display: none; }
    .head { flex-direction: column; gap: .3rem; padding-top: .8rem; }
    .head.tool { height: auto; padding: .6rem var(--side) .4rem; align-items: flex-start; }
    main.tool { height: auto; }
    nav { justify-content: flex-start; gap: .2rem 1rem; }
    nav a { min-height: 32px; display: inline-flex; align-items: center; }
  }
</style>
