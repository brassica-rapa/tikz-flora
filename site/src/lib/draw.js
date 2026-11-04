// Draws a page's flora from its scene (lua/flora/pdfout.lua M.scene: the
// PDF content stream with its resources as JSON) into an ImageBitmap,
// with flora's renderers (~/flora, the upstream engine): its reader turns
// the scene into a display list, then WebGL2 draws it, or the 2D canvas
// where WebGL2 is missing or when asked for ("canvas2d").
import { fromPdfScene, WebGLRenderer, drawCanvas2D } from "@alpaca-software/web-flora";

// One WebGL context for the worker's life: browsers allow only a few, and
// a context is costly to make.
let gl = null, glCanvas = null, glFailed = false;

// The scene `scene` (parsed JSON) drawn `px` device pixels wide. `view`
// {y, height} (bp from the page's foot) keeps only that band of the page.
// `listed`, when given, is called once the display list is read, before
// it is drawn. Returns { bitmap, renderer, ms, listMs }.
export function draw(scene, px, view, mode = "webgl", listed) {
  const t0 = performance.now();
  const list = fromPdfScene(scene);
  const listMs = performance.now() - t0;
  listed?.();
  const scale = px / scene.width;
  const h = view ? view.height : scene.height;
  // The band's top, in the display list's y-down units.
  const y0 = view ? scene.height - view.y - view.height : 0;
  const w = Math.round(px), hp = Math.round(h * scale);
  if (mode !== "canvas2d" && !glFailed) {
    try {
      glCanvas ??= new OffscreenCanvas(w, hp);
      gl ??= new WebGLRenderer(glCanvas);
      glCanvas.width = w;
      glCanvas.height = hp;
      gl.draw(list, { scale, y0 });
      return { bitmap: glCanvas.transferToImageBitmap(), renderer: "webgl", ms: performance.now() - t0, listMs };
    } catch (e) {
      // No WebGL2 (or no stencil): the 2D canvas from here on.
      if (!/WebGL2 is not available|no stencil/.test(String(e?.message))) throw e;
      glFailed = true;
    }
  }
  const c = new OffscreenCanvas(w, hp);
  drawCanvas2D(c.getContext("2d"), list, { scale, y0 });
  return { bitmap: c.transferToImageBitmap(), renderer: "canvas2d", ms: performance.now() - t0, listMs };
}
