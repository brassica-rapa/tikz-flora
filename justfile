set export

PATH := env("HOME") / "Library/TinyTeX/bin/universal-darwin" + ":" + env("PATH")
TEXINPUTS := "./tex//:"
export TEXMFCACHE := env("TEXMFCACHE", "/tmp/texmf-cache")
export TEXMFVAR := env("TEXMFVAR", "/tmp/texmf-cache")
# Values saved from the tuner override lua/flora/tune.lua when present.
# An interpreter with numpy and Pillow for tuner/; Homebrew's newest
# python3 may not have them yet.
PYTHON := env("FLORA_PYTHON", "python3")
FLORA_TUNE := if path_exists(justfile_directory() / "tune-local.lua") == "true" { justfile_directory() / "tune-local.lua" } else { "" }

# Compile a document in tex/ to build/<name>.pdf and a PNG preview.
build name="lorem" seed="1" dpi="200":
    mkdir -p build
    lualatex --shell-escape -interaction=nonstopmode -halt-on-error -output-directory=build \
        -jobname={{name}} "\def\florseed{ {{seed}} }\input{tex/{{name}}.tex}" > build/{{name}}.out || (tail -30 build/{{name}}.log; exit 1)
    pdftocairo -png -singlefile -r {{dpi}} build/{{name}}.pdf build/{{name}}
    grep -h 'flora:' build/{{name}}.log || true

# Run the Lua unit tests under texlua, and the tune.lua writer's test.
test:
    for f in tests/test_*.lua; do texlua "$f" || exit 1; done
    {{PYTHON}} -I tests/test_bake.py
    {{PYTHON}} -I tests/test_baked.py

# Bake procedural flora into lightweight transparent images (tex/baked/).
bake layout="left" seed="1" dpi="300":
    {{PYTHON}} tools/bake.py --layout={{layout}} --seed={{seed}} --dpi={{dpi}}

# Bake standard layouts for common seeds into tex/baked/.
bake-all:
    {{PYTHON}} tools/bake.py --batch

# The ornament gallery: every ornament kind, labelled, for three seeds
# (tex/gallery.tex), to build/gallery.pdf and .png.
gallery:
    just build gallery 1 100

# "Watch it grow": page PAGE of tex/NAME.tex as its flora grows, written to
# build/grow-NAME-PAGE.mp4 and .gif (tools/grow.sh; needs ffmpeg).
grow name="lorem" seed="1" page="1" fps="20" secs="8":
    tools/grow.sh {{name}} {{seed}} {{page}} {{fps}} {{secs}}

# The drop-in package: build/tikzflora.zip with the package, its Lua, the
# worked example and a latexmkrc that selects LuaLaTeX (also on Overleaf).
dist:
    rm -rf build/dist && mkdir -p build/dist/tikzflora/lua
    cp tex/tikzflora.sty tex/tikzflora-boot.lua tex/latexmkrc README.md LICENSE build/dist/tikzflora/
    cp tex/lorem.tex build/dist/tikzflora/example.tex
    cp -R lua/flora build/dist/tikzflora/lua/flora
    if [ -d tex/baked ]; then cp -R tex/baked build/dist/tikzflora/; fi
    rm -f build/tikzflora.zip
    cd build/dist && zip -qrX ../tikzflora.zip tikzflora
    @echo "dist: build/tikzflora.zip"

# Compiles the example from the unpacked zip alone, outside the repository
# and without its TEXINPUTS, as a user would.
test-dist: dist
    rm -rf build/test-dist && mkdir -p build/test-dist
    unzip -q build/tikzflora.zip -d build/test-dist
    cd build/test-dist/tikzflora && if command -v latexmk >/dev/null 2>&1; then env -u TEXINPUTS -u FLORA_TUNE latexmk -quiet example > latexmk.out 2>&1 || (tail -30 example.log; exit 1); else env -u TEXINPUTS -u FLORA_TUNE lualatex --shell-escape -interaction=nonstopmode example > latexmk.out 2>&1 || (tail -30 example.log; exit 1); fi
    test "$(pdfinfo build/test-dist/tikzflora/example.pdf | awk '/^Pages/ {print $2}')" = 7
    grep -q -E 'painted objects|\(baked\)' build/test-dist/tikzflora/example.log
    @echo "dist: example compiles from the zip"

# The browser mixer runs the generator under Lua 5.4 (wasmoon); LuaLaTeX
# runs Lua 5.3. Runs the Lua tests under 5.4 and checks both draw the same
# pages byte for byte. Needs Homebrew's lua@5.4.
LUA54 := env("FLORA_LUA54", "/opt/homebrew/opt/lua@5.4/bin/lua5.4")
test-lua54:
    for f in tests/test_*.lua; do {{LUA54}} "$f" || exit 1; done
    mkdir -p build
    texlua tests/parity.lua build/parity-53.txt
    {{LUA54}} tests/parity.lua build/parity-54.txt
    cmp build/parity-53.txt build/parity-54.txt && echo "lua54: identical to texlua"

# Assets for the site (site/) made from the example, tex/lorem.tex: the
# zip, each layout's measured layout and text page for the mixer, page
# renders, the grow animation and the link-preview image.
site-bake seed="3" CW="site/src/lib/colourways.json":
    just dist
    rm -rf site/public/bake site/public/img site/public/media build/site-bake
    mkdir -p site/public/bake site/public/img site/public/media build/site-bake
    cp build/tikzflora.zip site/public/
    for _ in 1 2; do FLORA_SPEC_DIR=build/site-bake lualatex -interaction=nonstopmode -halt-on-error -output-directory=build/site-bake -jobname=base "\def\florseed{ {{seed}} }\def\florapages{0}\input{tex/lorem.tex}" > build/site-bake/base.out || (tail -20 build/site-bake/base.log; exit 1); done
    for p in 1 2 3 4 6; do cp build/site-bake/spec-$p.lua site/public/bake/; pdftocairo -png -singlefile -r 110 -f $p -l $p build/site-bake/base.pdf site/public/bake/text-$p; done
    printf '%s\n' '[{"layout":"left","page":4,"label":"Left"},{"layout":"right","page":3,"label":"Right"},{"layout":"centered","page":6,"label":"Centred"},{"layout":"title","page":1,"label":"Title"},{"layout":"surround","page":2,"label":"Surround"}]' > site/public/bake/manifest.json
    just build lorem {{seed}} >/dev/null; just build lorem {{seed}} 110 >/dev/null
    pdftocairo -jpeg -jpegopt quality=86 -r 110 build/lorem.pdf site/public/img/page
    # Page 4 in each colourway of site/src/lib/colourways.json, grown as the
    # mixer grows it, and the first colourway's flora alone beside the guide.
    for i in 0 1 2; do s=$(jq -r ".[$i].seed" $CW) && p=$(jq -r ".[$i].palette | to_entries | map(\"\(.key)=\(.value)\") | join(\", \")" $CW) && texlua tools/preview.lua build/site-bake/spec-4.lua $s 4 build/site-bake/cw-$i.pdf - "fresh, visitors=1, palette={$p}" && pdftocairo -png -singlefile -r 110 build/site-bake/cw-$i.pdf build/site-bake/cw-$i && magick build/site-bake/cw-$i.png site/public/bake/text-4.png -compose multiply -composite -quality 86 site/public/img/colourway-$i.jpg || exit 1; done
    p=$(jq -r ".[0].palette | to_entries | map(\"\(.key)=\(.value)\") | join(\", \")" $CW) && texlua tools/preview.lua build/site-bake/spec-4.lua $(jq -r ".[0].seed" $CW) 4 build/site-bake/flora-4.pdf - "fresh, noheader, visitors=1, palette={$p}"
    pdftocairo -png -transp -singlefile -r 90 build/site-bake/flora-4.pdf build/site-bake/flora-4
    magick build/site-bake/flora-4.png -gravity west -crop 36%x100%+0+0 +repage site/public/img/flora-margin.png
    just grow lorem {{seed}} 3 20 8
    cp build/grow-lorem-3.mp4 site/public/media/grow.mp4
    cp build/grow-lorem-3.gif site/public/media/grow.gif
    magick -size 1200x630 xc:'#f5f2eb' \( site/public/img/colourway-0.jpg -resize x560 \) -geometry +12+35 -composite \( site/public/img/colourway-1.jpg -resize x560 \) -geometry +402+35 -composite \( site/public/img/colourway-2.jpg -resize x560 \) -geometry +792+35 -composite -quality 86 site/public/img/og.jpg

# The site with hot reload at http://127.0.0.1:5174/ (run site-bake first).
site-dev:
    cd site && npm ci --no-audit --no-fund --silent && npx vite --port 5174 --host 127.0.0.1

# Drives the built site in headless Chrome (site/tests/e2e.mjs).
test-site:
    cd site && npm ci --no-audit --no-fund --silent && npm run build --silent
    node site/tests/e2e.mjs

# Builds and publishes the site at https://flora.alpacasoft.dev (Cloudflare
# Workers; wrangler creates the DNS record for the custom domain).
site-deploy: site-bake
    cd site && npm ci --no-audit --no-fund --silent && npm run build --silent && npx wrangler deploy

# Integration test for the shipout measurer (needs lualatex).
test-tex:
    mkdir -p build
    lualatex -interaction=nonstopmode -halt-on-error -output-directory=build tests/measure.tex > build/measure.out || (grep -A3 '^!' build/measure.log; exit 1)
    grep -q 'measure: ok' build/measure.log && echo "measure: ok"

# The component tuner for lua/flora/tune.lua at http://127.0.0.1:8766/:
# builds the Svelte app in tuner/ and serves it with the render API.
tuner:
    cd tuner && npm ci --no-audit --no-fund --silent && npm run build --silent
    {{PYTHON}} -I tuner/server.py

# The tuner app with hot reload at http://127.0.0.1:5173/tuner/dist/; it
# forwards renders to a running `just tuner`.
tuner-dev:
    cd tuner && npm run dev

# Drives the built tuner in headless Chrome (tuner/tests/e2e.mjs).
test-tuner:
    cd tuner && npm ci --no-audit --no-fund --silent && npm run build --silent
    FLORA_PYTHON={{PYTHON}} node tuner/tests/e2e.mjs

# The TeX-free preview (tools/preview.lua) must match a real compile pixel
# for pixel once laid under the same page's text.
test-preview seed="3" page="2":
    mkdir -p build/test-preview
    FLORA_SPEC_DIR=build/test-preview lualatex -interaction=nonstopmode -halt-on-error -output-directory=build/test-preview -jobname=base "\def\florapages{0}\input{tex/reference.tex}" > /dev/null
    lualatex -interaction=nonstopmode -halt-on-error -output-directory=build/test-preview -jobname=real "\def\florseed{ {{seed}} }\def\florapages{ {{page}} }\input{tex/reference.tex}" > /dev/null
    texlua tools/preview.lua build/test-preview/spec-{{page}}.lua {{seed}} {{page}} build/test-preview/flora.pdf
    cd build/test-preview && pdftocairo -png -singlefile -r 110 flora.pdf flora && pdftocairo -png -singlefile -r 110 -f {{page}} -l {{page}} base.pdf text && pdftocairo -png -singlefile -r 110 -f {{page}} -l {{page}} real.pdf real
    cd build/test-preview && magick flora.png text.png -compose multiply -composite combo.png && magick compare -metric AE -fuzz 1% combo.png real.png null: 2>diff.txt; d=$(cut -d' ' -f1 diff.txt); echo "preview: $d pixels differ"; test "$d" = "0"