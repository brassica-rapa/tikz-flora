# tikz-flora (Baked Edition)

> **A high-performance fork of [tikz-flora](https://github.com/wn-mitch/tikz-flora) that automatically bakes procedural watercolor flora into optimized transparent images which can be cached, keeping output PDFs compact, easy to render, and quick to recompile.**

Watercolour flora grown in the margins of LuaLaTeX documents. Every page grows its own plant around the text it holds: stems, leaves, blooms, sprays, gilt, and if you like, bees, butterflies, birds and snails.

---

## Why This Fork Exists

The original `tikz-flora` prioritizes high quality by individually storing every petal, wash, blotch, vein, and speckle which PDF readers render with vector commands. This leads to massive file sizes and laggy PDF readers

### What This Fork Solves

* **Small, Lightweight PDFs**: Floral artwork is computed procedurally in Lua and rasterized on-demand into crisp, high-resolution transparent PNGs via `pdftocairo`. Output PDFs drop from tens of megabytes to ~1 MB per page with standard FlateDecode compression.
* **Deterministic Layout & Clearance Hashing**: Unchanged pages hit the cache instantly, slashing multi-page compilation times from 20+ seconds down to under 5 seconds. The cache key in `flora-cache/` is derived from an exact cryptographic hash of the page's geometry, seed, palette, DPI, and the precise bounding boxes of your text. When you edit text, margins, or seeds, new matching flora is baked automatically.

## Origins

This project would not exist without two others:

- The r/LaTeX thread
  [How do you make these flowers in LaTeX?](https://old.reddit.com/r/LaTeX/comments/1xixznw/how_do_you_make_these_flowers_in_latex/),
  whose photographed page is the reference this renderer is measured
  against.
- Kevin Raymond's [florilegium](https://github.com/kevinraymond/florilegium)
  (MIT), whose grown margins, watch-it-grow animation and visitors this
  package follows.

This fork stands on two earlier ones:

- [wn-mitch/tikz-flora](https://github.com/wn-mitch/tikz-flora) (MIT), the
  generator itself: every petal, wash, leaf and ornament.
- [samzarr/flora-baked](https://github.com/samzarr/flora-baked) (MIT), whose
  baking cache (`tools/bake.py`, `tests/test_baked.*` and the baking code in
  `lua/flora/init.lua`) rasterises each page into a hashed image so PDFs stay
  small and recompiles fast. It is merged here with its history kept, so the
  commits remain under their author. The Windows fixes to it are this fork's.

This fork adds the `+bright` ink modifier, the `cross` and `buttercup` blooms, the
`flower`, `petals` and `hero` settings, and the inflorescences.

The ink colours are Pilot iroshizuku ramps measured by
[madoromi](https://madoromi.moonwit.ch/#palettes/colours). The growth follows
Wong, Zongker and Salesin,
[Computer-Generated Floral Ornament](https://grail.cs.washington.edu/projects/ornament/ornament.pdf)
(SIGGRAPH 1998).

tikz-flora was written with Claude Code, Anthropic's coding agent. The art
direction, the tuning against the reference and the choice of what to keep
were done by hand.

## Setup
**Locally:**
You need a TeX distribution with **LuaLaTeX** (TeX Live 2023 or later,
MiKTeX, or TinyTeX) and either **pdftocairo** (from `poppler-utils`) or **Ghostscript** (`gs`, standard in TeX Live and Overleaf). Check with `lualatex --version` and `gs -v` or `pdftocairo -v`. The example also uses
`lipsum` (`tlmgr install lipsum` on TinyTeX).

1. Download `tikzflora.zip` from the site, or build it with `just dist`.
2. Unzip it into a folder of its own; its files sit at the zip's root. It
   holds `tikzflora.sty`, `tikzflora-boot.lua`, the generator
   in `lua/flora/`, and `example.tex`.
3. Put your document next to `tikzflora.sty` (or copy the `.sty`, the boot
   file and `lua/` next to your document).
4. Compile with LuaLaTeX and shell-escape:
   ```bash
   lualatex --shell-escape example.tex
   ```
   Or use `latexmk example` (the included `latexmkrc` configures LuaLaTeX with shell-escape automatically).

**Overleaf:** New Project, Upload Project, choose `tikzflora.zip`. You must manually change the compiler to Lualatex: in the dropdown next to the recompile button choose settings.

**Overleaf:** New Project, Upload Project, choose `tikzflora.zip`. The
`latexmkrc` in the zip sets the compiler to LuaLaTeX; otherwise choose it
under Menu, Compiler. The zip holds two documents; if Overleaf opens
`titles.tex`, set Menu, Main document to `example.tex`. To add flora to an
existing project, upload `tikzflora.sty`, `tikzflora-boot.lua` and the
`lua` folder to the project's top level, beside its main document.

A minimal document:

```latex
\documentclass{article}
\usepackage[inner=2cm,outer=2cm,top=2cm,bottom=2cm]{geometry}
\usepackage{tikzflora}
\florasetup{layout=surround, seed=7}
\begin{document}
Text.
\end{document}
```

## Settings

`\florasetup{...}` sets keys for the rest of the document, from the page it
is on. `\florathispage{...}` sets them for one page only. Mistakes stop the
compile with a message naming the key.

| Key | Values | Effect |
|---|---|---|
| `layout` | `left`, `right`, `centered`, `split`, `title`, `surround`, `flank`, `wreath`, `bouquet`, `scrollwork` | Where the flora grows (below) |
| `seed` | a number, or `random` | Which garden; each page varies it |
| `mix` | `{kind=weight, ...}` | How much of each kind: 1 usual, 0 none, 2 about double |
| `density` | 0 to 10 | Fuller (above 1) or airier (below 1) |
| `visitors` | 0 to 10 | The weight of every visitor at once |
| `palette` | `{part=ink, ...}` | What paints the `hero`, `blooms`, `leaves`, `leaflets`, `stems`, `sprays`, `ghost`, `cartouche` |
| `colourway` | `spring`, `summer`, `autumn` (or `fall`), `winter`, `ember`, `plum`, `rose`, `original` | A whole palette at once; a `palette` after it changes single parts |
| `spin` | a whole number | Picks other inks for parts set to `random`; the shapes stay |
| `flower` | `fan`, `round`, `soft`, `obovate`, `wedge`, `cross`, `buttercup` | The bloom style of the hero and the blooms (below) |
| `hero` | `bloom`, `raceme`, `corymb`, `panicle` | What crowns the main stem: the hero bloom, or a painted head of blooms (below) |
| `animals` | `classic`, `painted` | How the bee and the songbird are drawn (below) |
| `petals` | 3 to 12 | How many petals every bloom has; inflorescence florets follow it |
| `ornaments` | `{kind=weight, ...}` | How often each ornament kind is picked for its place; 0 never |
| `gilt` | `raster`, `vector` | Ornament gold computed per pixel as images (the default), or built of flat-coloured strips |
| `giltdpi` | 50 to 1200 | Resolution of raster gilt; 600 by default, lower compiles faster |
| `giltenv` | `studio`, `mirror` | The look of raster gilt: a studio window over dark ground (default), or the vector relief's sky and horizon |
| `giltlook` | `{key=value, ...}` | Changes keys of that look, e.g. `giltlook={horizon=0.1, grain=0}`: light, horizon, sky, ground, highlight, grain, sparkle, shadow and more (`lua/flora/gilt_look.lua` lists every key and its range) |
| `backdrop` | `light` (default), `dark`, or a dark `#rrggbb` | What the flora is painted over. On `dark` every ink is painted light, as if lit, and gold stays gold; set the page to match, e.g. `\pagecolor[HTML]{0A1014}` |
| `cache` | `true` (default), `false` | Keeps each page's flora in a folder `<jobname>-flora/` beside the PDF so a later compile reuses it (see Long documents) |
| `baked` | `true`, `false` (default) | Rasterise each page's flora to a transparent PNG instead of keeping vectors: much smaller and quicker to recompile, no longer vector (see Baking) |
| `dpi` | 50 to 1200 | Resolution of baked pages in DPI (default `150`) |

Mix kinds: `bloom`, `soft`, `lily`, `ghost`, `umbel`, `cyme`
(forget-me-nots), `gyps` (baby's breath), `leaves`, `leaflets`, `sprays`,
`curls`, `density`, `bee`, `butterfly`, `bird`, `snail`. Visitors are off
unless you give them weight, and so are the inflorescences `raceme`,
`corymb` and `panicle` (below). The mix also weighs the shapes drawn:
`feather`, `acanthus` and `lance` for large leaves (small leaves are
always lance leaves), and `fan` and `round` for small blooms, so
`mix={acanthus=3, feather=0}` grows broad lobed leaves. The guide's
"Every option" lists every key and value, read from the package.

Palette values are `look` (the default gradients), an ink group (`blue`,
`blue-grey`, `teal`, `green`, `violet`, `warm`, `earth`, `gold`) or one ink
by name, such as `kon-peki` (all of them are in `lua/flora/inks.lua`).
`random` paints that part in one ink picked per page. The pick has its own
random stream, so changing `spin` changes only the colours: every stem,
leaf and bloom stays where it was.

`sprays` paints the forget-me-nots, baby's breath and umbels, `ghost` the
pale ghost bloom, and `cartouche` the sky in the star cartouche. A non-blue
ink also repaints the rims, grain and contours of the part it paints, so a
page with every part set keeps only a few navy pen lines.

Ornaments fill places on the page: the `cartouche` panel, the `header`
mark on the running-head rule, the `pendant` in the foot's corner, the
larger `gilt` in the foliage's gaps, and on title pages a `crest` where the
crown meets, a `flourish` under the title, a `tailpiece` under the last
line and a piece in each foot `corner`. The `flank` layout's foot piece is
a `crest`, and the `scrollwork` frame takes a `crest` at its head and a
`tailpiece` at its foot. Each place picks one kind by
weight, so `ornaments={moon=3, night=0}` favours the crescent moon
cartouche and drops the night sky; setting every kind of a place to 0
leaves it empty. `just gallery` (or `\floragallery` in a `tikzpicture`)
draws every kind with the name to weigh it by. The kinds:

- cartouche: `night`, `sun`, `moon`, `constellation`, `planet`,
  `armillary`, `scrolled`, `strapwork`
- header: `compass`, `rosette`, `sunburst`, `quatrefoil`
- pendant: `knot`, `medallion`, `zodiac_pendant`
- crest: `sun_crest`, `compass_rose`, `armillary_crest`, `zodiac`, `wreath`
- flourish: `swash`, `fleuron_rule`, `headpiece`
- tailpiece: `cul_de_lampe`, `hedera`, `garland`
- corner: `bracket`, `fan`, `corner_leaf`
- gilt: `gilt_cross`, `gilt_rosette`, `gilt_dotted`, `gilt_lozenge`,
  `gilt_star`, `gilt_crescent`, `gilt_trefoil`

A new kind is a Lua file that calls `register` in
`lua/flora/ornaments.lua` (which explains the fields) and is listed in its
`MODULES`; the gallery and the tests pick it up, and `tests/test_ornaments.lua`
holds it to its box.

```latex
\florasetup{layout=split, visitors=0.5, mix={lily=2, umbel=0},
  palette={hero=murasaki-shikibu, blooms=warm, leaves=teal}}
```

### Yellow flowers, petal counts and inflorescences

The blue-ink pipeline reads every ink at the look's lightness, which is dark:
at that depth a yellow turns olive. Put `+bright` after any ink or ink group
(`gold+bright`, `daikokuten+bright`, `ama-iro+bright`) and it is read in its
own lighter range instead: the look's lightness is laid over the ink's
measured ramp, so the ink keeps its hue and chroma and only its darkness
changes. `gold+bright` is the clean yellows of the original `gold` inks,
`ama-iro+bright` a luminous sky blue where `ama-iro` is dark navy, and
`murasaki-shikibu+bright` a lilac. `color.bright.depth` in
`lua/flora/tune.lua` sets how far the deepest tones go: 0 stays a clean light
tone, 1 reaches the ink's densest stroke. A bright yellow draws its stems and
pen lines in green, and its florets keep a pale eye and a green pistil.
`random+bright` picks a random ink, lightened. Name one ink, not a group, for
a part whose petals should match: a group picks a different ink for each
petal, so `gold+bright` mixes the lemon of `daikokuten` with the lime of
`hotaru-bi`.

Two bloom styles are yellow by default: `cross`, a crucifer's four overlapping
spoon petals round a green pistil and six stamens (rapeseed, wallflower,
mustard), and `buttercup`, five round glossy petals round a green boss in a
ring of gold stamens, both in `daikokuten+bright`. `flower=cross` makes the hero and the blooms that style
and paints the sprays in its ink; `palette` still overrides any part, and
`petals` changes the count of any style (`flower=wedge, petals=6`). Leaves are
not recoloured: set `palette={leaves=green}` as well.

`mix={raceme=1}`, `corymb` and `panicle` grow inflorescences in the holes:
a raceme opens from the bottom up with buds crowded at the tip and seed pods
below, a corymb is a level head on pedicels of graded length, a panicle is a
raceme with side racemes. The `inflorescence` keys in `lua/flora/tune.lua`
set how many florets, their size, stalks, spread, sweep and pods.

```latex
\florasetup{flower=cross, palette={leaves=green, leaflets=green, ghost=daikokuten+bright},
  mix={raceme=3, corymb=3, cyme=0, soft=0}}
```

A painted head can crown the page instead of the single hero bloom:
`hero=raceme`, `hero=corymb` or `hero=panicle`. It is built from the main
stem's last stretch, which it carries on to a fine tip, and from full
watercolour blooms in the florets' style (`flower`, else `cross`). Florets
are scattered round the axis by the golden angle, so they fill the head
evenly, and each has a depth: they are painted back to front, the back ones
smaller, paler and more tilted, the front ones larger and nearly face-on,
each foreshortened in perspective and shading the ones behind it. Buds crowd
the tip, pedicels run to every floret, and a raceme has seed pods below.
The `head` keys in `lua/flora/tune.lua` set how many florets, their size,
the head's length and width, how many get the full wash (`detail`: more is
richer and slower), their tilt, shadow and fade, and `cup`, how concave each
floret is: its outward petal is tilted back toward the viewer, so the flower
opens like a shallow cup (0 is flat, the default is 0.7).

```latex
\florasetup{hero=raceme, flower=cross, palette={leaves=green, leaflets=green}}
```

### Painted animals

`animals=painted` draws the bee and the songbird in a more modelled way;
`classic` (the default) is unchanged, so a page that does not ask for it
comes out exactly as before.

- **Bird.** Head, neck and body are one smooth union of shapes (signed
  distance fields, `sdf.lua`). The tail is individual feathers behind the
  body, darker, with round or pointed tips; the wing is one merged shape of
  coverts and primaries, with feather lines; the belly is its own colour.
  Beak angle and shape, eye size and build vary per bird.
- **Bee.** A stout, nearly round abdomen overlapped by the thorax and head,
  with bands that run under the thorax. It has four wings, a forewing and a
  smaller hindwing each side, rooted on the thorax and swept back; the near
  pair is glassy over the body, the far pair a ghost. Antennae are elbowed.

Both take their colour from the page's palette: the back (bird) or abdomen
(bee) is the `blooms` ink, and the belly (bird) or the dark parts (bee) the
`leaves` ink; when the palette gives none, the bee is honey gold.

```latex
\florasetup{animals=painted, palette={blooms=ama-iro, leaves=daikokuten+bright}}
```

### Baking

Two ways keep a long document quick, and they suit different uses.

- **The page cache** (`cache=true`, the default) keeps each page's flora as
  a small vector PDF in `<jobname>-flora/`, so a later compile embeds it
  instead of growing it again. The art stays vector.
- **Baking** (`baked=true`) rasterises each page's flora to a transparent
  PNG in `flora-cache/`, named by a hash of the page's seed and open space,
  at `dpi` (default 150). A baked page is far smaller on disk and compiles
  quickest, but it is no longer vector. It needs `--shell-escape` and
  `pdftocairo` (poppler) or Ghostscript the first time a page is grown.
  Baking follows [flora-baked](https://github.com/samzarr/flora-baked) by
  samzarr, whose approach and `tools/bake.py` it builds on.

On Overleaf, a baked page can be kept by opening "logs and output files",
then "other logs and output files", finding the `.png` for the page and
putting it in the `flora-cache` folder.

### Layouts

- `left`: the left margin (the default).
- `right`: the right margin.
- `centered`: both side margins, with two different plants.
- `split`: the outer margin of a two-sided document. It is on the right of
  odd pages and the left of even ones.
- `title`: a crown over a title. Wrap the title in
  `\begin{floratitle} ... \end{floratitle}`; without it the first block
  of lines is crowned.
- `surround`: a wreath round the text block, for title pages and contents.

Four more layouts are for title pages, after engraved and hand-coloured
flower books of the nineteenth century. Each frames the lines in
`floratitle` (or the first block of lines without it):

- `flank`: a plant up each side of the page's contents, their roots
  meeting at the foot round a crest.
- `wreath`: an open oval garland round the title, tied at its foot.
- `bouquet`: one upright bouquet tied with a bow, behind the title, with
  each title line on a ribbon.
- `scrollwork`: an oval gilt scroll frame round the title, with a crest at
  its head, scrolls at its foot and the flora twined over it.

The oval of `wreath` and `scrollwork` spans the page's width and keeps to
the room between the title and the nearest lines above and below it.

The flora fills whatever margins the page has, so give it room with
`geometry` (about 5 cm for a side margin, or 3 cm all round for
`surround`).

### Lettering

`\floraletters` draws a line of display capitals as an engraver lettered
them, from the font's own outlines, in the font and size in force:

```latex
{\fontsize{46}{52}\selectfont\floraletters{FLORA'S}\par}
{\fontsize{30}{36}\selectfont\floraletters[style=engraved, arch=24]{DICTIONARY}\par}
```

- `style`: `outline` (the letter drawn round), `shaded` (outlined, with a
  hatched shadow; the default) or `engraved` (the face ruled with fine
  lines over a solid shadow).
- `arch`: the degrees the baseline bends through. Positive arches the
  middle up, negative sags it; 0 (the default) keeps it straight.
- `ink`: an iroshizuku ink by name for the line work, or `black` (the
  default).

It needs an OpenType or TrueType font, as LuaLaTeX's default Latin Modern
and any `fontspec` font are; with another font the text is set as usual,
with a warning in the log. The flora keeps clear of the lettering as it
does of text.

It also grows into gaps in the text. A gap between lines taller than about
three lines (40 pt), such as a `\vspace` left for a figure, opens across
the text's full width and the flora reaches into it. The space below a
short last page fills the same way.

`tex/lorem.tex` (`example.tex` in the zip) uses the first six layouts,
with a comment at every setting; `tex/titles.tex` (`titles.tex` in the
zip) has a title page in each of the other four, lettered with
`\floraletters`.

### Long documents

Growing a page's flora takes a few seconds. Each page's flora is kept in
a folder `<jobname>-flora/` beside the PDF, named by everything it
depends on (the page's layout, the settings and the package's code), so
the next compile reuses every page whose text did not move. The second
and third runs that LaTeX and `latexmk` make cost almost nothing, and
an edit grows again only the pages it reflows. The folder holds about
as much again as the PDF; pages no compile has used for three runs are
deleted, and the folder can be deleted at any time.
`\florasetup{cache=false}` grows every page afresh and keeps nothing.

A `lualatex --draftmode` run writes no PDF, so it grows no flora.
`\floraoff` stops the flora from the page it falls on and `\floraon`
starts it again, so a long document can be drafted with the flora off
(`\floraoff` in the preamble) or with it only on the chapters being
worked on.

The flora is tens of megabytes of PDF drawing per page before
compression, so the package lowers LaTeX's compression level from 9 to
4: the PDF is about 7% larger and compiles in about half the
time. Set `\pdfvariable compresslevel=9` after `\usepackage{tikzflora}`
for the smallest file.

## Working on tikz-flora

The repository uses [just](https://github.com/casey/just). These recipes
add the TinyTeX binaries to `PATH`:

- `just build NAME [SEED]`: compile `tex/NAME.tex` to `build/` with a PNG
  preview. `just build lorem` builds the example; `just build reference`
  builds a page laid out like the reference photo, which the tuner uses.
- `just grow NAME SEED PAGE`: build `build/grow-NAME-PAGE.mp4` and `.gif`
  of a page as it grows. It needs ffmpeg, poppler (`pdftocairo`) and
  ImageMagick.
- `just gallery`: draw every ornament kind, labelled, to
  `build/gallery.pdf` (`tex/gallery.tex`).
- `just dist`: build `build/tikzflora.zip`. `just test-dist` compiles the
  example from the unpacked zip alone.
- `just bake [LAYOUT] [SEED]` and `just bake-all`: bake procedural flora
  into 300 DPI transparent images in `tex/baked/` (`tools/bake.py`).
- `just test`: run the Lua and Python unit tests. `just test-tex` and
  `just test-preview` check against real compiles.
- `just site-bake`, `just site-dev`, `just test-site`, `just site-deploy`:
  build, test and publish the site. `site/README.md` explains them.
- `just tuner`: run a local web app with a slider for every setting in
  `lua/flora/tune.lua`, drawing `tex/reference.tex` beside the de-warped
  reference photo when `tex/reference/rectified.png` is present (it is not
  tracked). It needs Python 3 with numpy and Pillow, and Node.

## Licence

MIT. See `LICENSE`.
