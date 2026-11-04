# flora.alpacasoft.dev

The tikz-flora site, a Vite and Svelte app served by a Cloudflare Worker.
It has four pages, each its own HTML entry with its own link preview:

| Page | Entry | Contents |
|---|---|---|
| `/` | `index.html`, `src/pages/Home.svelte` | The title page, the colourways, the grow animation, the example document and the contents |
| `/mixer/` | `mixer/index.html`, `src/lib/Mixer.svelte` | The live mixer, full screen; `?way=N` opens on colourway N |
| `/ornaments/` | `ornaments/index.html`, `src/lib/Gallery.svelte` | Every ornament kind, by slot |
| `/guide/` | `guide/index.html`, `src/lib/Guide.svelte` | Setup, settings and credits |

`src/lib/Shell.svelte` gives every page its running head and colophon, and
`src/app.css` holds the shared type, colours and the book grid. Only the
mixer and the ornaments page load the generator.

## Recipes

Run these from the repository root. They need Node and the TeX tools
listed in the root README.

- `just site-bake [SEED]`: compile `tex/lorem.tex` and write the
  generated assets to `public/`. Run it once before `site-dev`, and again
  after changing the example or the generator's look.
- `just site-dev`: serve the site with hot reload at
  http://127.0.0.1:5174/.
- `just test-site`: build the site and drive it in headless Chrome
  (`tests/e2e.mjs`). The test checks the assets, each page's link preview
  and internal links, grows a page in the mixer, checks that the controls scroll without
  moving the page, and checks the setup line the mixer writes. Set
  `SITE_URL=https://flora.alpacasoft.dev/` and run
  `node site/tests/e2e.mjs` to check the deployed site instead.
- `just garden`: build the garden for other web pages into
  `build/garden/`: `garden.js` and `assets/`, served together from any
  folder. `src/lib/garden.js` documents its interface; the garden's
  layout is `lua/flora/garden.lua`.
- `just test-garden`: build the garden, test its clock
  (`tests/garden.mjs`) and grow it in headless Chrome from a folder of
  its own (`tests/garden-e2e.mjs`).
- `just renderers`: serve the renderer bench at
  http://127.0.0.1:5175/tools/renderers.html. It grows one garden and
  draws it with flora's WebGL2 and 2D canvas renderers. It shows each
  renderer's median time and a map of where the two pictures differ. The
  page's URL holds the form, so a link reproduces a run. The bench is a
  development page and is not part of the build.
- `just renderers-bench [key=value ...]`: run the same bench in headless
  Chrome and print its table (`tests/renderers-bench.mjs`). The keys are
  the form's fields, e.g. `dpr=1 settings=backdrop=dark`. The bench fails
  when the renderers differ at more than 3% of inked samples.
- `just site-deploy`: bake, build and publish with `npx wrangler deploy`.
  It needs a `wrangler login` to the Cloudflare account that holds
  `alpacasoft.dev`. Wrangler creates the DNS record for the custom domain
  set in `wrangler.jsonc`.

## Baked assets

`site-bake` writes these files. They are build output and are not
committed.

| Path | Contents |
|---|---|
| `public/tikzflora.zip` | The drop-in package from `just dist` |
| `public/bake/spec-N.lua` | The measured page specs (text block, lines, header) of example pages 1, 2, 3, 4 and 6 |
| `public/bake/text-N.png` | The text of each of those pages, without flora |
| `public/bake/manifest.json` | Which baked page each mixer layout uses |
| `public/img/page-N.jpg` | Every page of the finished example |
| `public/img/colourway-N.jpg` | Page 4 in each colourway of `src/lib/colourways.json` |
| `public/img/flora-margin.png` | The first colourway's flora alone, beside the guide |
| `public/img/og.jpg` | The 1200 x 630 link preview, from the colourway pages |
| `public/media/grow.mp4`, `grow.gif` | Page 3 growing |

## Colourways

`src/lib/colourways.json` lists the colourways the site opens with: a
name, a seed and an ink for every palette part. The home page and the
mixer read it, and `site-bake` renders each one with `tools/preview.lua` on
page 4, grown with the mixer's starting mix (the `fresh, visitors=1`
settings), so "Use these inks" reproduces the picture exactly.

## The mixer

The mixer runs the package's own Lua in the browser. `vite.config.js`
lets the app import `../lua/flora/*.lua`, so the site always runs the same
generator as the package.

1. `src/lib/render.worker.js` mounts the Lua files into wasmoon (Lua 5.4
   in WebAssembly) in a Web Worker.
2. For each change, `src/lib/Mixer.svelte` sends the worker the baked
   spec of the chosen layout with the seed, mix, ornaments, palette and
   spin. The worker calls `Compose.page`.
3. The worker draws the page with `src/lib/draw.js`, which hands the PDF
   content stream `paint.lua` writes (`pdfout.lua` `M.scene`) to the
   `flora` package (github.com/wn-mitch/flora, pinned in `package.json`):
   its reader turns the stream into a display list and its WebGL2
   renderer draws it on an OffscreenCanvas. Where WebGL2 is missing, or
   with `?renderer=canvas2d`, flora's 2D canvas renderer draws it. The
   worker returns a bitmap, and the baked text image is multiplied over
   it. With `?renderer=pdf` the worker returns PDF bytes instead and
   pdf.js draws them, for comparison. The status line names the renderer.

   flora's reader knows only the operators in `src/lib/scene-ops.json`;
   `tests/test_scene_ops.lua` fails when `paint.lua` writes any other,
   and `tests/e2e.mjs` checks that flora's list matches the file and
   that both renderers match pdf.js on the same page.
4. `src/lib/setup.js` writes the `\florasetup{...}` line for the current
   settings.

LuaLaTeX runs Lua 5.3 and wasmoon runs Lua 5.4. `just test-lua54` checks
that both paint identical pages.

## Serving

`worker.js` answers `/media/*` with byte ranges (206 responses), because
iOS Safari plays MP4 only from a server that honours `Range` and Workers
static assets ignore it. Every other path goes to the static assets in
`dist/`.
