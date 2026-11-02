-- Entry points called from TeX.

local M = {}

-- Send a painted page to TeX. PGF code goes through TeX one chunk at a
-- time (each chunk begins with a control sequence, so concatenating them
-- without line ends is safe). A PDF content stream is held until TeX reaches
-- M.flush, which must run inside the picture, after the resource
-- registrations; it never passes through TeX's input.
function M.typeset(pt)
  for _, d in ipairs(pt.defs) do tex.sprint(d) end
  if pt.backend == "pdf" then
    M._pending = pt:body()
    tex.sprint("\\directlua{flora.flush()}")
  else
    for _, c in ipairs(pt.out) do tex.sprint(c) end
  end
  texio.write_nl("log", string.format("flora: %d painted objects", pt.count))
end

-- Write the held PDF content as one literal, in the same coordinate mode
-- PGF's own literals use, so it shares the picture's origin.
function M.flush()
  local n = node.new("whatsit", "pdf_literal")
  n.mode = 0
  n.data = M._pending or ""
  M._pending = nil
  node.write(n)
end

-- Settings from \florasetup (the document's) and \florathispage (the next
-- page shipped only); see settings.lua for the keys.
M.settings = {}
M.once = nil

local function report(err)
  tex.error("tikzflora: " .. tostring(err):gsub("^.-:%d+: ", ""))
end

function M.setup(s, once)
  local Settings = require("flora.settings")
  local ok, t = pcall(Settings.parse, s)
  if not ok then return report(t) end
  if once then
    M.once = Settings.merge(M.once, t)
  else
    M.settings = Settings.merge(M.settings, t)
  end
end

-- Leave a named mark at this point of the page (measure.lua).
function M.mark(name)
  require("flora.measure").mark(name)
end

function M.specimens(seed)
  local spec = require("flora.specimen")
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%dpt}{%dpt}}\\pgfusepath{use as bounding box}",
    spec.width, spec.height))
  M.typeset(spec.draw(seed))
end

-- The ornament gallery (gallery.lua): every kind for `seeds` seeds, each
-- labelled with its name and the key that weighs it.
function M.gallery(seeds)
  local pt, cells, w, h = require("flora.gallery").sheet(nil, tonumber(seeds) or 3)
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%.2fpt}{%.2fpt}}\\pgfusepath{use as bounding box}", w, h))
  M.typeset(pt)
  for _, c in ipairs(cells) do
    if c.seed == 1 then
      tex.sprint(string.format(
        "\\pgftext[left,base,at=\\pgfqpoint{%.2fpt}{%.2fpt}]{\\footnotesize %s \\texttt{\\color{gray}%s}}",
        c.box[1], c.box[4] + 5 + c.lift, c.label, (c.name:gsub("_", "\\_"))))
    end
  end
end

local function pt_of(s)
  return tonumber((tostring(s):gsub("pt$", "")))
end

-- The seed for a page: a fixed document seed varied by page number, or the
-- clock when the document asks for "random".
function M.seed(base, page)
  if base == "random" then
    M._clock = M._clock or os.time()
    base = M._clock
  end
  return (tonumber(base) or 1) * 7919 + page * 104729
end

-- Canonical hash of a page's layout specification (including open space / lines).
-- Two pages have the same hash if and only if their settings, geometry, seed,
-- and text-clearing open space match identically.
function M.spec_hash(spec)
  local Serial = require("flora.serial")
  local layout = spec.layout or "left"
  if layout == "split" then
    layout = (spec.page or 1) % 2 == 1 and "right" or "left"
  end
  local canonical = {
    seed = spec.seed,
    layout = layout,
    width = spec.width,
    height = spec.height,
    text = spec.text,
    header_y = spec.header_y,
    lines = spec.lines,
    title = spec.title,
    mix = spec.mix,
    ornaments = spec.ornaments,
    palette = spec.palette,
    spin = spec.spin,
    flower = spec.flower,
    petals = spec.petals,
    head = spec.head,
    dpi = spec.dpi or 150,
  }
  local encoded = Serial.encode(canonical)
  if md5 and md5.sumhexa then
    return md5.sumhexa(encoded):sub(1, 16)
  else
    local h = 5381
    for i = 1, #encoded do
      h = ((h * 33) + encoded:byte(i)) % 0x100000000
    end
    return string.format("%08x", h)
  end
end

local function file_exists(path)
  local fh = io.open(path, "rb")
  if fh then fh:close() return true end
  return false
end

local function find_kpse(n, ftype)
  if not (kpse and kpse.find_file) then return nil end
  local ok, res = pcall(kpse.find_file, n, ftype)
  return ok and res or nil
end

-- Find a pre-baked image for this page.
-- CRITICAL CONSTRAINT: Pre-baked images must ONLY match if the hash of the
-- seed, layout, and exact open space (lines) matches. Never fall back to
-- unhashed or mismatched images.
function M.find_baked(spec, set)
  if set and set.baked == false then return nil end

  local hash = M.spec_hash(spec)
  local layout = spec.layout or "left"
  if layout == "split" then
    layout = (spec.page or 1) % 2 == 1 and "right" or "left"
  end
  local doc_seed = spec.doc_seed or tostring(spec.seed)
  local p = spec.page or 1

  local names = {
    string.format("flora-%s-s%s-p%d-%s.png", layout, doc_seed, p, hash),
    string.format("flora-%s-%s.png", layout, hash),
    string.format("flora-%s.png", hash),
  }

  for _, name in ipairs(names) do
    for _, dir in ipairs({ "flora-cache/", ".flora-cache/", "tex/baked/", "baked/", "./", "tex/" }) do
      local path = dir .. name
      if file_exists(path) then return path end
    end
    local kpath = find_kpse(name, "graphic/image") or find_kpse("flora-cache/" .. name, "graphic/image")
      or find_kpse(".flora-cache/" .. name, "graphic/image") or find_kpse("baked/" .. name, "graphic/image")
      or find_kpse("tex/baked/" .. name, "graphic/image")
    if kpath and file_exists(kpath) then return kpath end
  end
  return nil
end

-- Bake a page to a transparent PNG file using Compose, Pdf, and pdftocairo.
function M.bake_page(spec, target_png, dpi)
  local dir = target_png:match("^(.-)/[^/]+$")
  if dir and dir ~= "" and lfs and lfs.mkdir then
    pcall(lfs.mkdir, dir)
  end

  local pdfout = require("flora.pdfout")
  local Compose = require("flora.compose")
  local pt = Compose.page(spec)
  local tmp_pdf = target_png:gsub("%.png$", ".tmp.pdf")
  pdfout.write(tmp_pdf, pt, spec.width, spec.height)

  local prefix = target_png:gsub("%.png$", "")
  local res

  -- Windows runs os.execute through cmd.exe: no `command -v`, /dev/null or
  -- %q-quoted paths, and Ghostscript is gswin64c.
  local windows = package.config:sub(1, 1) == "\\"
  local quiet = windows and ">NUL 2>&1" or ">/dev/null 2>&1"
  local function q(path) return '"' .. path:gsub('"', "") .. '"' end
  if M._has_cairo == nil then
    local check = os.execute("pdftocairo -v " .. quiet)
    M._has_cairo = (check == 0 or check == true)
  end

  -- 1. Try pdftocairo if available
  if M._has_cairo then
    local cmd_cairo = string.format("pdftocairo -png -transp -singlefile -r %d %s %s", dpi or 150, q(tmp_pdf), q(prefix))
    res = os.execute(cmd_cairo)
  end

  -- 2. Fallback to Ghostscript (standard on TeX Live / Overleaf)
  if not file_exists(target_png) then
    local cmd_gs = string.format("%s -dSAFER -dBATCH -dNOPAUSE -q -sDEVICE=pngalpha -r%d -sOutputFile=%s %s", windows and "gswin64c" or "gs", dpi or 150, q(target_png), q(tmp_pdf))
    res = os.execute(cmd_gs)
  end

  pcall(os.remove, tmp_pdf)

  if file_exists(target_png) then
    return true, target_png
  end
  return false, "rasterization failed: neither 'pdftocairo' nor 'gs' (Ghostscript) produced an image (last exit status: " .. tostring(res) .. ")"
end

-- Draw the flora for one page as a page-sized pgfpicture whose origin is the
-- lower-left corner of the paper. Dimensions arrive as TeX "<n>pt" strings.
--   a.width, a.height, a.text_x0, a.text_y0, a.text_x1, a.text_y1,
--   a.header_y, a.seed, a.page, a.box (the register holding the page,
--   whose ink is measured so flora can grow into space the text leaves),
--   and a.only (a page number; other pages are left bare)
--
-- With FLORA_SPEC_DIR set, each page's measured layout (everything but the
-- seed) is also written to <dir>/spec-<page>.lua, for tools/preview.lua.
function M.page(a)
  local dump = os.getenv("FLORA_SPEC_DIR")
  local skip = a.only and a.only ~= "" and tonumber(a.only) ~= a.page
  if skip and not (dump and dump ~= "") then return end
  local set = require("flora.settings").merge(M.settings, M.once)
  M.once = nil
  local lines, marks
  if a.box then lines, marks = require("flora.measure").boxes(a.box, pt_of(a.height)) end
  local spec = {
    width = pt_of(a.width), height = pt_of(a.height),
    text = { x0 = pt_of(a.text_x0), y0 = pt_of(a.text_y0), x1 = pt_of(a.text_x1), y1 = pt_of(a.text_y1) },
    header_y = a.header_y and pt_of(a.header_y),
    seed = M.seed(set.seed or a.seed, a.page),
    lines = lines, layout = set.layout, page = a.page, mix = set.mix, ornaments = set.ornaments, palette = set.palette, spin = set.spin,
    flower = set.flower, petals = set.petals, head = set.hero,
    doc_seed = tostring(set.seed or a.seed),
    dpi = set.dpi or 150,
  }
  if marks and marks["title-start"] and lines then
    spec.title = require("flora.frames").between(lines, marks["title-start"], marks["title-end"] or 0)
  end
  if dump and dump ~= "" then
    local f = assert(io.open(string.format("%s/spec-%d.lua", dump, a.page), "w"))
    local saved = {}
    for k, v in pairs(spec) do if k ~= "seed" then saved[k] = v end end
    f:write(require("flora.serial").encode(saved), "\n")
    f:close()
  end
  if skip then return end

  -- If user explicitly asked for raw vectors via baked=false, typeset directly
  if set.baked == false then
    local pt = require("flora.compose").page(spec)
    tex.sprint("\\begin{pgfpicture}")
    tex.sprint(string.format(
      "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%.2fpt}{%.2fpt}}\\pgfusepath{use as bounding box}",
      spec.width, spec.height))
    M.typeset(pt)
    tex.sprint("\\end{pgfpicture}")
    texio.write_nl("log", string.format("flora: page %d coverage %.2f (vectors)", a.page, pt.coverage or 0))
    return
  end

  -- Default baked mode: look for existing pre-baked image matching exact seed and open space
  local baked = M.find_baked(spec, set)
  if not baked then
    -- If shell escape is disabled, we cannot auto-rasterize with pdftocairo
    if status and status.shell_escape ~= 1 then
      local reason = "LuaLaTeX was run without --shell-escape. Re-run with 'lualatex --shell-escape " .. (tex.jobname or "document") .. ".tex'."
      tex.error(string.format("tikzflora: unable to bake flora for page %d.\n%s\nNo pre-baked image matching this seed and open space was found.", a.page, reason))
      return
    end

    -- Not found: compute flowers and bake to cache
    local hash = M.spec_hash(spec)
    local layout = (spec.layout == "split") and ((spec.page % 2 == 1) and "right" or "left") or (spec.layout or "left")
    local cache_dir = "flora-cache"
    local target_png = string.format("%s/flora-%s-s%s-p%d-%s.png", cache_dir, layout, spec.doc_seed, spec.page, hash)
    local ok, err = M.bake_page(spec, target_png, spec.dpi)
    if ok then
      baked = target_png
    else
      tex.error(string.format("tikzflora: unable to bake flora for page %d.\nFailed to rasterize flora. Please ensure 'pdftocairo' (poppler-utils) or 'gs' (Ghostscript) is installed and in your PATH.\n(%s)", a.page, tostring(err)))
      return
    end
  end

  -- Embed the baked image
  tex.sprint("\\begin{pgfpicture}")
  tex.sprint(string.format(
    "\\pgfpathrectangle{\\pgfpointorigin}{\\pgfqpoint{%.2fpt}{%.2fpt}}\\pgfusepath{use as bounding box}",
    spec.width, spec.height))
  tex.sprint(string.format(
    "\\pgftext[left,bottom,at=\\pgfpointorigin]{\\pgfimage[width=%.2fpt,height=%.2fpt]{%s}}",
    spec.width, spec.height, baked:gsub("\\", "/")))
  tex.sprint("\\end{pgfpicture}")
  texio.write_nl("log", string.format("flora: page %d (baked) %s", a.page, baked))
end

return M
