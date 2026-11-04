<script>
  // Picks what paints one part: its original look, a random ink, an ink
  // group or one ink. Every choice shows its colour, so no ink needs to be
  // known by name. The list opens in place, below the control.
  import { tick } from "svelte";
  import { face, strip, describe } from "./ink.js";

  let { part, label = part, value = $bindable(), meta, onchange } = $props();
  let open = $state(false);
  let root, trigger, panel;

  // Groups in the order shown: the colours furthest from the original
  // blue first.
  const ORDER = ["warm", "violet", "gold", "earth", "green", "teal", "blue-grey", "blue"];
  const RANDOM = ["momiji", "sui-gyoku", "yama-budo", "hotaru-bi"];

  const ramps = $derived(meta.ramps);
  const groups = $derived(ORDER.filter((g) => meta.groupInks[g]));
  // Each ink once, under the first group in ORDER that holds it.
  const sections = $derived.by(() => {
    const seen = new Set();
    const out = groups.map((g) => ({ g, inks: meta.groupInks[g].filter((n) => !seen.has(n) && seen.add(n)) }));
    const rest = meta.inks.filter((n) => !seen.has(n));
    if (rest.length) out.push({ g: "other", inks: rest });
    return out;
  });
  const isInk = (v) => Boolean(ramps[v]);
  const isGroup = (v) => Boolean(meta.groupInks[v]);
  const title = (v) => v === "look" ? "Original" : v === "random" ? "Random ink" : isInk(v) ? describe(ramps[v]) : `${v} inks`;

  async function toggle() {
    open = !open;
    if (open) {
      await tick();
      (panel.querySelector('[aria-selected="true"]') ?? panel.querySelector("[role=option]"))?.focus();
    }
  }

  function choose(v) {
    value = v;
    open = false;
    trigger.focus();
    onchange?.();
  }

  // Arrow keys, Home and End move between options; Escape closes.
  function keys(e) {
    const opts = [...panel.querySelectorAll("[role=option]")];
    const i = opts.indexOf(document.activeElement);
    let j = null;
    if (e.key === "ArrowDown" || e.key === "ArrowRight") j = Math.min(opts.length - 1, i + 1);
    else if (e.key === "ArrowUp" || e.key === "ArrowLeft") j = Math.max(0, i - 1);
    else if (e.key === "Home") j = 0;
    else if (e.key === "End") j = opts.length - 1;
    else if (e.key === "Escape") { open = false; trigger.focus(); e.preventDefault(); return; }
    if (j !== null) { opts[j].focus(); e.preventDefault(); }
  }

  function outside(e) {
    if (open && root && !root.contains(e.target)) open = false;
  }
</script>

<svelte:window onclick={outside} />

<div class="picker" bind:this={root}>
  <button type="button" class="current" bind:this={trigger} aria-haspopup="listbox" aria-expanded={open}
    aria-label={`${label}: ${title(value)}${isInk(value) ? ` (${value})` : ""}`} onclick={toggle}>
    {#if isInk(value)}
      <span class="well"><span class="chip" style:background={strip(ramps[value])}></span></span>
    {:else if isGroup(value)}
      <span class="well"><span class="chip dots">{#each meta.groupInks[value] as n}<i style:background={face(ramps[n])}></i>{/each}</span></span>
    {:else if value === "random"}
      <span class="well"><span class="chip dots">{#each RANDOM as n}<i style:background={face(ramps[n])}></i>{/each}</span></span>
    {:else}
      <span class="well"><span class="chip original"></span></span>
    {/if}
    <span class="text"><span>{title(value)}</span>{#if isInk(value)}<code>{value}</code>{/if}</span>
  </button>

  {#if open}
    <!-- svelte-ignore a11y_interactive_supports_focus -->
    <div class="panel" role="listbox" tabindex="-1" aria-label={`Ink for ${label}`} bind:this={panel} onkeydown={keys}>
      <div class="plain">
        <button type="button" role="option" aria-selected={value === "look"} onclick={() => choose("look")}>
          <span class="well"><span class="chip original"></span></span>Original
        </button>
        <button type="button" role="option" aria-selected={value === "random"} onclick={() => choose("random")}>
          <span class="well"><span class="chip dots">{#each RANDOM as n}<i style:background={face(ramps[n])}></i>{/each}</span></span>Random ink
        </button>
      </div>
      <p class="head">Groups: each shape picks one of the group's inks</p>
      <div class="groups">
        {#each groups as g}
          <button type="button" role="option" aria-selected={value === g} onclick={() => choose(g)}>
            <span class="well"><span class="chip dots">{#each meta.groupInks[g] as n}<i style:background={face(ramps[n])}></i>{/each}</span></span>
            {g}
          </button>
        {/each}
      </div>
      {#each sections as s}
        <p class="head">{s.g}</p>
        <div class="inks">
          {#each s.inks as n}
            <button type="button" role="option" aria-selected={value === n} aria-label={`${describe(ramps[n])} (${n})`} onclick={() => choose(n)}>
              <span class="well wide"><span class="ramp" style:background={strip(ramps[n])}></span></span>
              <span class="text"><span>{describe(ramps[n])}</span><code>{n}</code></span>
            </button>
          {/each}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  /* The trigger takes the row's control column; the open list takes the
     whole row, below it. */
  .picker { display: contents; }
  .current { grid-column: 2 / 4; }
  .panel { grid-column: 1 / -1; }
  button { font: inherit; color: inherit; cursor: pointer; text-align: left; }
  .current {
    display: flex; align-items: center; gap: .55rem; width: 100%; min-width: 0; min-height: 36px;
    padding: .25rem .45rem; border: 1px solid var(--control); background: transparent;
  }
  .current:hover { border-color: var(--ink); }
  .text { display: flex; flex-direction: column; min-width: 0; line-height: 1.2; }
  .text span { font-size: .98rem; }
  .text code { background: none; padding: 0; color: var(--muted); font-size: .72rem; }
  /* Swatches sit on white, as the inks do on the page. */
  .well { flex: none; display: inline-flex; padding: 2px; background: #fff; border: 1px solid #b8b2a5; }
  .well.wide { display: flex; }
  .chip { width: 2.4rem; height: .95rem; }
  .dots { display: inline-flex; }
  .dots i { flex: 1; }
  .chip.original { background: linear-gradient(90deg, oklab(0.40 -0.01 -0.19), oklab(0.62 -0.08 -0.12), oklab(0.90 -0.03 -0.04)); }
  .ramp { display: block; width: 100%; height: 1.4rem; }
  .panel { margin-top: .35rem; padding: .55rem; border: 1px solid var(--ink); background: var(--paper); }
  .head { margin: .7rem 0 .3rem; font-size: .95rem; color: var(--rubric); letter-spacing: .07em; font-variant-caps: all-small-caps; }
  .plain, .groups, .inks { display: grid; grid-template-columns: 1fr 1fr; gap: .4rem; }
  .plain button, .groups button {
    display: flex; align-items: center; gap: .45rem; padding: .3rem .4rem; min-height: 36px;
    border: 1px solid transparent; background: transparent; font-size: .95rem;
  }
  .inks button { display: flex; flex-direction: column; gap: .3rem; padding: .3rem; border: 1px solid transparent; background: transparent; }
  [role="option"]:hover { border-color: var(--control); }
  [aria-selected="true"] { border-color: var(--ink); box-shadow: inset 0 0 0 1px var(--ink); }
  @media (max-width: 860px) {
    .plain button, .groups button { min-height: 44px; }
  }
</style>
