<script>
  // A viewer for the home page's pages: open(items, i) shows items[i]
  // ({ small, large, alt, caption }) fitted to the screen, loading the
  // large copy (site-bake's img/large, twice as fine) over the small one.
  // Clicking the page zooms it to the large copy's full size about the
  // point clicked, and again fits it; the arrow keys and buttons step
  // through `items`; Escape, the close button or a click outside closes it.
  // It is the site's own UI, so the margin garden does not measure it
  // (data-flora-ui).
  let dialog, scroller;
  let items = $state([]);
  let at = $state(0);
  let zoomed = $state(false);
  let loaded = $state("");
  const item = $derived(items[at]);

  export function open(list, i) {
    items = list;
    show(i);
    dialog.showModal();
  }

  function show(i) {
    at = (i + items.length) % items.length;
    zoomed = false;
    const it = items[at];
    if (loaded === it.large) return;
    const im = new Image();
    im.onload = () => { if (items[at] === it) loaded = it.large; };
    im.src = it.large;
  }

  // Zoom about the point clicked: the same spot of the page stays under
  // the pointer.
  function toggle(e) {
    const img = e.currentTarget;
    if (zoomed) {
      zoomed = false;
      return;
    }
    const r = img.getBoundingClientRect();
    const fx = (e.clientX - r.left) / r.width, fy = (e.clientY - r.top) / r.height;
    const px = e.clientX, py = e.clientY;
    zoomed = true;
    requestAnimationFrame(() => {
      const z = img.getBoundingClientRect();
      scroller.scrollLeft += z.left + fx * z.width - px;
      scroller.scrollTop += z.top + fy * z.height - py;
    });
  }

  function key(e) {
    if (items.length < 2) return;
    if (e.key === "ArrowRight") { e.preventDefault(); show(at + 1); }
    if (e.key === "ArrowLeft") { e.preventDefault(); show(at - 1); }
  }

  // A click on the backdrop (the dialog itself, outside its content) closes.
  function outside(e) {
    if (e.target === dialog || e.target === scroller) dialog.close();
  }
</script>

<dialog class="lightbox" bind:this={dialog} data-flora-ui aria-label={item?.alt ?? "Page"}
  onkeydown={key} onclick={outside} onclose={() => { zoomed = false; }}>
  {#if item}
    <div class="scroller" class:zoomed bind:this={scroller}>
      <img src={loaded === item.large ? item.large : item.small} alt={item.alt}
        class:zoomed onclick={toggle} title={zoomed ? "Fit to the screen" : "See at full size"}>
    </div>
    <div class="bar">
      {#if item.caption}<p class="caption">{item.caption}</p>{/if}
      {#if items.length > 1}
        <button type="button" onclick={() => show(at - 1)} aria-label="Previous page">←</button>
        <span class="count">{at + 1} / {items.length}</span>
        <button type="button" onclick={() => show(at + 1)} aria-label="Next page">→</button>
      {/if}
    </div>
    <button type="button" class="close" onclick={() => dialog.close()} aria-label="Close">×</button>
  {/if}
</dialog>

<style>
  .lightbox {
    width: 100vw; height: 100dvh; max-width: none; max-height: none; margin: 0; padding: 0; border: 0;
    background: transparent; color: var(--ink); overflow: hidden;
  }
  .lightbox::backdrop { background: oklch(25% 0.02 70 / .82); }
  :global(html:has(dialog.lightbox[open])) { overflow: hidden; }
  .scroller { position: absolute; inset: 0 0 3.4rem; display: grid; place-items: center; overflow: auto; overscroll-behavior: contain; }
  .scroller.zoomed { place-items: start; }
  img {
    display: block; max-width: calc(100vw - 2rem); max-height: calc(100dvh - 5rem); width: auto; height: auto;
    background: white; box-shadow: 0 20px 60px -20px oklch(0% 0 0 / .6); cursor: zoom-in;
  }
  img.zoomed { max-width: none; max-height: none; cursor: zoom-out; margin: 1rem; }
  .bar {
    position: absolute; left: 0; right: 0; bottom: 0; height: 3.4rem; display: flex; align-items: center; justify-content: center; gap: .8rem;
    padding: 0 1rem; color: var(--paper);
  }
  .bar .caption { margin: 0 auto 0 0; color: inherit; opacity: .85; }
  .count { font-variant-numeric: tabular-nums; opacity: .85; }
  button {
    min-width: 40px; min-height: 40px; border: 1px solid oklch(100% 0 0 / .35); background: transparent; color: inherit;
    font: inherit; font-size: 1.2rem; cursor: pointer; border-radius: 0;
  }
  button:hover, button:focus-visible { border-color: var(--paper); }
  .close { position: absolute; top: 1rem; right: 1rem; color: var(--paper); background: oklch(25% 0.02 70 / .6); }
</style>
