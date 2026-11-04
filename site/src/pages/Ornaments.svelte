<script>
  import Shell from "../lib/Shell.svelte";
  import Gallery from "../lib/Gallery.svelte";
</script>

<Shell page="ornaments">
  <article class="book">
    <header class="lead">
      <p class="sc rubric">The gilt</p>
      <h1>Ornaments</h1>
    </header>
    <p class="intro">Every place on a page that takes gilt (the cartouche, the
      header mark, the pendant, and on title pages the crest, flourish,
      tailpiece and corners) picks one ornament kind by weight. Set the
      weights with <code>{"ornaments={moon=2, night=0}"}</code> or in the
      <a href="/mixer/">mixer</a>.</p>
    <p class="note aside caption">A new kind is one Lua file that registers
      itself; this page draws it with the rest. Each kind is shown with three
      seeds and labelled with the name its weight goes by.</p>
    <div class="wide" id="gallery">
      <Gallery />
    </div>
  </article>
</Shell>

<style>
  .lead { padding-top: clamp(2rem, 6vh, 4rem); margin-bottom: 1.2rem; }
  .lead p { margin: 0 0 .2rem; }
  h1 { font-size: clamp(2.6rem, 5vw, 3.8rem); margin: 0; }
  .intro { font-size: 1.25rem; }
  .aside { align-self: end; margin-bottom: 1rem; }
  #gallery { margin-top: 1.4rem; }
</style>
