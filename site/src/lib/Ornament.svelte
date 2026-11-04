<script>
  // One of the package's ornaments set into the page, drawn by its engine
  // (ornaments-client.js) as it nears the viewport and gilded in from its
  // centre outward as it comes into view. `slot` is the ornament slot it
  // takes a kind from (flourish, tailpiece, crest, ...), `seed` keeps each
  // place's pick its own, `width` (CSS px, at most the column) and
  // `aspect` (width / height) its box. Decoration only: hidden from
  // assistive technology.
  import { onMount } from "svelte";
  let { slot, name = undefined, seed = 0, width = 420, aspect = 6 } = $props();
  let box, canvas;
  let state = $state("waiting");
  let kind = $state("");

  onMount(() => {
    let gone = false, drawn = false, seenYet = false;
    let drawOrnament, onChoose;
    const draw = async () => {
      if (gone) return;
      ({ drawOrnament, onChoose } = await import("./ornaments-client.js"));
      const w = Math.round(box.clientWidth), h = Math.round(w / aspect);
      if (w < 40 || gone) return;
      const out = await drawOrnament({ slot, name, seed, w, h });
      if (gone) { out.bitmap.close?.(); return; }
      canvas.width = out.bitmap.width;
      canvas.height = out.bitmap.height;
      canvas.getContext("2d").drawImage(out.bitmap, 0, 0);
      out.bitmap.close?.();
      kind = out.name;
      if (state === "waiting") state = seenYet ? "gilt" : "drawn";
    };
    const near = new IntersectionObserver((es) => {
      if (drawn || !es.some((e) => e.isIntersecting)) return;
      drawn = true;
      near.disconnect();
      draw().then(() => {
        unsub = onChoose((s) => { if (s === slot && !name) draw(); });
      }, (e) => console.error(e));
    }, { rootMargin: "600px 0px" });
    const seen = new IntersectionObserver((es) => {
      if (!es.some((e) => e.isIntersecting)) return;
      seen.disconnect();
      seenYet = true;
      if (state === "drawn") state = "gilt";
    }, { threshold: 0.4 });
    let unsub = () => {};
    near.observe(box);
    seen.observe(box);
    return () => {
      gone = true;
      near.disconnect();
      seen.disconnect();
      unsub();
    };
  });
</script>

<div class="ornament {state}" bind:this={box} style:max-width="{width}px" style:aspect-ratio={aspect}
  aria-hidden="true" data-slot={slot} data-kind={kind}>
  <canvas bind:this={canvas}></canvas>
</div>

<style>
  .ornament { width: 100%; margin: 0 auto; }
  canvas { display: block; width: 100%; height: 100%; clip-path: inset(0 50% 0 50%); opacity: 0; }
  /* Gilded in from the centre outward once seen; it waits, drawn, till then. */
  .gilt canvas {
    clip-path: inset(0 0 0 0); opacity: 1;
    transition: clip-path 2.2s cubic-bezier(.3, .1, .2, 1), opacity 1.2s ease-out;
  }
  @media (prefers-reduced-motion: reduce) {
    canvas, .gilt canvas { clip-path: none; opacity: 1; transition: none; }
  }
</style>
