-- Raster gilt (orn_raster.lua) and its rasteriser (raster.lua).
local H = dofile("tests/helper.lua")
local R = require("flora.raster")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Orn = require("flora.ornaments")
local Rng = require("flora.rng")
local Gild = require("flora.orn_gild")
local Raster = require("flora.orn_raster")
local Settings = require("flora.settings")
local Compose = require("flora.compose")

local function sum(a)
  local s = 0
  for _, v in ipairs(a) do s = s + v end
  return s
end

local square = G.polyline({ { 10, 10 }, { 30, 10 }, { 30, 30 }, { 10, 30 } }, true)

-- Coverage is area: a square off the pixel grid and a circle cover their
-- own area in pixels, and every value stays within 0-1.
do
  local g = R.grid(0, 0, 40, 40, 0.37)
  local sq = G.polyline({ { 5.13, 7.29 }, { 27.6, 7.29 }, { 27.6, 31.05 }, { 5.13, 31.05 } }, true)
  local cov = R.fill(g, R.flatten(g, sq))
  local want = (27.6 - 5.13) * (31.05 - 7.29) / 0.37 ^ 2
  H.check(math.abs(sum(cov) - want) / want < 2e-3, string.format("square covers %.1f px, not %.1f", sum(cov), want))
  local circ = R.fill(g, R.flatten(g, { { "o", 20, 20, 12 } }))
  want = math.pi * 144 / 0.37 ^ 2
  H.check(math.abs(sum(circ) - want) / want < 5e-3, string.format("circle covers %.1f px, not %.1f", sum(circ), want))
  for i = 1, g.n do H.check(circ[i] >= 0 and circ[i] <= 1, "coverage out of range") end
end

-- Fill rules: a square with a same-direction inner square is solid under
-- nonzero and has a hole under even-odd.
do
  local g = R.grid(0, 0, 40, 40, 0.5)
  local inner = G.polyline({ { 15, 15 }, { 25, 15 }, { 25, 25 }, { 15, 25 } }, true)
  local both = {}
  for _, c in ipairs(square) do both[#both + 1] = c end
  for _, c in ipairs(inner) do both[#both + 1] = c end
  local nz, eo = sum(R.fill(g, R.flatten(g, both))), sum(R.fill(g, R.flatten(g, both), true))
  H.check(math.abs(nz - 1600) < 1, "nonzero fill is not solid: " .. nz)
  H.check(math.abs(eo - 1200) < 1, "even-odd fill has no hole: " .. eo)
end

-- A stroke covers its length times its width plus the round caps, and
-- its inside distance peaks at half its width on the centre line.
do
  local g = R.grid(0, 0, 40, 20, 0.25)
  local cov, din = R.stroke(g, R.flatten(g, { { "m", 5, 10 }, { "l", 35, 10 } }), 2 / 0.25)
  local want = (30 * 4 + math.pi * 4) / 0.0625
  H.check(math.abs(sum(cov) - want) / want < 0.01, string.format("stroke covers %.0f px, not %.0f", sum(cov), want))
  local peak = -1
  for i = 1, g.n do if din[i] > peak then peak = din[i] end end
  H.check(math.abs(peak - 8) < 0.6, "stroke centre lies " .. peak .. " px inside, not 8")
end

-- The distance transform is exact for a disc: the centre is its radius
-- inside, and distance rises toward the centre.
do
  local g = R.grid(0, 0, 40, 40, 0.5)
  local cov = R.fill(g, R.flatten(g, { { "o", 20, 20, 10 } }))
  local d = R.inside_distance(g, cov)
  -- Pixel (col 40, row 41) has its centre 0.71 px from the disc's.
  local centre = d[40 * g.w + 40]
  H.check(math.abs(centre - (20 - math.sqrt(0.5))) < 0.75, "disc centre is " .. centre .. " px inside, not 19.3")
  H.check(d[40 * g.w + 30] < centre and d[40 * g.w + 30] > 0, "distance does not rise toward the centre")
  H.check(d[1] <= 0, "a pixel outside the disc has a positive distance")
end

-- The image's alpha is the shape's coverage: with no shadow, alpha over a
-- gilt disc matches the rasterised disc pixel for pixel (to a byte).
do
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  pt.gilt_dpi = 300
  Raster.add(pt, "fill", { { { "o", 50, 50, 8 } } }, { bevel = 0.5, shadow = 0 })
  local p = pt.gilt_pending
  local im = Raster.render(p, 300)
  local s = 72.27 / 300
  local g = { x0 = im.x0, y1 = im.y1, w = im.w, h = im.h, s = s, n = im.w * im.h }
  local cov = R.fill(g, R.flatten(g, { { "o", 50, 50, 8 } }))
  local worst = 0
  for i = 1, g.n do
    local a = im.alpha:byte(i) / 255
    worst = math.max(worst, math.abs(a - cov[i]))
  end
  H.check(#im.alpha == g.n and #im.rgb == 3 * g.n, "image data has the wrong size")
  H.check(worst <= 1 / 255 + 1e-9, "alpha differs from the disc's coverage by " .. worst)
  H.check(im.x0 < 42 and im.x1 > 58 and im.y0 < 42 and im.y1 > 58, "the image does not span the disc")
  -- The upper-left half of the dome, facing the light, is brighter on
  -- average than the lower-right half.
  local lit, far, nl, nf = 0, 0, 0, 0
  for row = 1, im.h do
    for col = 1, im.w do
      local k = (row - 1) * im.w + col
      if im.alpha:byte(k) == 255 then
        local l = im.rgb:byte(3 * k - 2) + im.rgb:byte(3 * k - 1) + im.rgb:byte(3 * k)
        local side = (col - im.w / 2) + (row - im.h / 2)
        if side < -2 then lit, nl = lit + l, nl + 1 elseif side > 2 then far, nf = far + l, nf + 1 end
      end
    end
  end
  H.check(lit / nl > far / nf + 20, string.format("raster gilt is not lit from the upper left (%.0f vs %.0f)", lit / nl, far / nf))
  -- The mirror look reflects other surroundings through the same
  -- coverage, still lit from the upper left.
  local mi = Raster.render(p, 300, nil, "mirror")
  H.check(mi.alpha == im.alpha and mi.rgb ~= im.rgb, "the mirror look changed the coverage, or nothing")
  lit, far, nl, nf = 0, 0, 0, 0
  for row = 1, mi.h do
    for col = 1, mi.w do
      local k = (row - 1) * mi.w + col
      if mi.alpha:byte(k) == 255 then
        local l = mi.rgb:byte(3 * k - 2) + mi.rgb:byte(3 * k - 1) + mi.rgb:byte(3 * k)
        local side = (col - mi.w / 2) + (row - mi.h / 2)
        if side < -2 then lit, nl = lit + l, nl + 1 elseif side > 2 then far, nf = far + l, nf + 1 end
      end
    end
  end
  H.check(lit / nl > far / nf + 20, string.format("the mirror look is not lit from the upper left (%.0f vs %.0f)", lit / nl, far / nf))
end

-- Rendered over one fixed frame, so separate renders line up pixel for
-- pixel: shapes added by add(kind, paths, o) in turn, at `dpi`.
local function framed(dpi, frame, adds)
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  for _, a in ipairs(adds) do Raster.add(pt, a[1], a[2], a[3]) end
  local p = pt.gilt_pending
  p.x0, p.y0, p.x1, p.y1 = frame[1], frame[2], frame[3], frame[4]
  return Raster.render(p, dpi)
end

-- Crossing bars: a gold bar under a copper bar painted next. A shape is
-- shaded from its own coverage alone: inside the crossing the image is
-- exactly the top bar painted alone, and wherever the bottom bar shows,
-- exactly the bottom bar painted alone.
do
  local function rect(x0, y0, x1, y1) return G.polyline({ { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }, true) end
  local bottom = { "fill", { rect(10, 44, 90, 56) }, { bevel = 0.8, shadow = 0 } }
  local top = { "fill", { rect(44, 10, 56, 90) }, { bevel = 0.8, shadow = 0, tone = "shade" } }
  local frame = { 0, 0, 100, 100 }
  local both = framed(300, frame, { bottom, top })
  local over = framed(300, frame, { top })
  local under = framed(300, frame, { bottom })
  local n_over, bad_over, n_under, bad_under = 0, 0, 0, 0
  for k = 1, both.w * both.h do
    local same = both.rgb:sub(3 * k - 2, 3 * k)
    if over.alpha:byte(k) == 255 and under.alpha:byte(k) == 255 then
      n_over = n_over + 1
      if same ~= over.rgb:sub(3 * k - 2, 3 * k) then bad_over = bad_over + 1 end
    elseif under.alpha:byte(k) == 255 and over.alpha:byte(k) == 0 then
      n_under = n_under + 1
      if same ~= under.rgb:sub(3 * k - 2, 3 * k) then bad_under = bad_under + 1 end
    end
  end
  H.check(n_over > 1000 and bad_over == 0, string.format("%d of %d crossing pixels differ from the top bar alone", bad_over, n_over))
  H.check(n_under > 1000 and bad_under == 0, string.format("%d of %d visible bottom-bar pixels differ from the bar alone", bad_under, n_under))
  -- Where the top bar's edge crosses the bottom bar, a pixel shows some
  -- of each: its colour lies between theirs, never a bright or dark
  -- hairline from a surface tilted between the two.
  local n_edge, bad_edge = 0, 0
  for k = 1, both.w * both.h do
    local a = over.alpha:byte(k)
    if a > 0 and a < 255 and under.alpha:byte(k) == 255 then
      n_edge = n_edge + 1
      for i = 3 * k - 2, 3 * k do
        local x, lo, hi = both.rgb:byte(i), over.rgb:byte(i), under.rgb:byte(i)
        if lo > hi then lo, hi = hi, lo end
        if x < lo - 2 or x > hi + 2 then bad_edge = bad_edge + 1 break end
      end
    end
  end
  H.check(n_edge > 50 and bad_edge == 0, string.format("%d of %d pixels on the top bar's edge leave the range of the two bars' colours", bad_edge, n_edge))
end

-- A ray in two faces, gold above copper, meeting along its axis: the
-- faces rise together to a ridge on the axis. The ridge is no groove
-- (never darker than both faces beside it) and no string of beads (its
-- brightness runs smoothly along the axis). Crossing bars, which share no
-- edge, never rise together.
do
  local c, tip = { 10, 50 }, { 90, 50 }
  local lit = { "fill", { G.polyline({ c, tip, { 50, 58 } }, true) }, { bevel = 0.8, shadow = 0 } }
  local shade = { "fill", { G.polyline({ c, tip, { 50, 42 } }, true) }, { bevel = 0.8, shadow = 0, tone = "shade" } }
  -- Half-point pixels, set so a row of pixel centres lies on the axis;
  -- no grain, to see the relief alone.
  Raster.texture = false
  local im = framed(144.54, { 0, -0.25, 100, 100.25 }, { lit, shade })
  Raster.texture = true
  local s = 0.5
  local axis = math.floor((im.y1 - 50) / s) + 1
  H.check(math.abs(im.y1 - (axis - 0.5) * s - 50) < 1e-9, "the test's pixel rows miss the axis")
  local function lum(x, row)
    local k = (row - 1) * im.w + math.floor((x - im.x0) / s) + 1
    return im.rgb:byte(3 * k - 2) + im.rgb:byte(3 * k - 1) + im.rgb:byte(3 * k)
  end
  local function alpha(x, row) return im.alpha:byte((row - 1) * im.w + math.floor((x - im.x0) / s) + 1) end
  local grooves, seams, worst, prev2, prev = 0, 0, 0, nil, nil
  -- Along the axis past the faces' widest point (x 55 to 75 pt), where
  -- each face is one plane.
  for x = 55.25, 75, 0.5 do
    local ridge, above, below = lum(x, axis), lum(x, axis - 2), lum(x, axis + 2)
    if ridge < math.min(above, below) - 6 then grooves = grooves + 1 end
    if alpha(x, axis) < 255 then seams = seams + 1 end
    if prev2 then worst = math.max(worst, math.abs(ridge - 2 * prev + prev2)) end
    prev2, prev = prev, ridge
  end
  H.check(seams == 0, seams .. " pixels of the ray's ridge let the paper through")
  H.check(grooves == 0, grooves .. " pixels of the ray's ridge are a dark groove")
  H.check(worst <= 12, "the ray's ridge is beaded: brightness jumps by " .. worst .. " between neighbouring pixels")
  local Relief = require("flora.raster_relief")
  local function piece(call, tone, pts)
    local g = R.grid(0, 0, 100, 100, 1)
    local polys = R.flatten(g, G.polyline(pts, true))
    local segs = {}
    for i = 1, #polys[1] - 2, 2 do segs[#segs + 1] = { polys[1][i], polys[1][i + 1], polys[1][i + 2], polys[1][i + 3] } end
    return { kind = "fill", call = call, tone = tone, segs = segs, win = { c0 = 0, r0 = 0, w = 100, h = 100 } }
  end
  local ray = Relief.groups({ piece(1, 0, { c, tip, { 50, 58 } }), piece(2, 1, { c, tip, { 50, 42 } }) })
  local cross = Relief.groups({ piece(1, 0, { { 10, 44 }, { 90, 44 }, { 90, 56 }, { 10, 56 } }),
    piece(2, 1, { { 44, 10 }, { 56, 10 }, { 56, 90 }, { 44, 90 } }) })
  H.check(#ray == 1 and #cross == 2, string.format("faces sharing an edge make %d group(s), crossing bars %d", #ray, #cross))
  -- Faces on the same side of a common edge overlap rather than meet:
  -- each keeps its own relief.
  local stacked = Relief.groups({ piece(1, 0, { c, tip, { 50, 58 } }), piece(2, 1, { c, tip, { 50, 54 } }) })
  H.check(#stacked == 2, "faces overlapping along a common edge rise together")

  -- A four-pointed star as the compass rose draws it: all copper faces,
  -- then all gold ones, every ray from the centre. A face's base runs
  -- along its neighbour's axis, and meets the opposite ray's base edge to
  -- edge, but its partner is the other half of its own ray alone.
  local star = { shade = {}, lit = {} }
  for k = 0, 3 do
    local a = math.pi / 2 + k * math.pi / 2
    local tip = G.polar({ 50, 50 }, a, 40)
    star.lit[k + 1] = { { 50, 50 }, tip, G.polar({ 50, 50 }, a + math.pi / 2, 6) }
    star.shade[k + 1] = { { 50, 50 }, tip, G.polar({ 50, 50 }, a - math.pi / 2, 6) }
  end
  local pieces = {}
  for k = 1, 4 do pieces[k] = piece(1, 1, star.shade[k]) end
  for k = 1, 4 do pieces[4 + k] = piece(2, 0, star.lit[k]) end
  local own = 0
  for _, grp in ipairs(Relief.groups(pieces)) do
    if #grp == 2 and grp[1].segs[1][3] == grp[2].segs[1][3] and grp[1].segs[1][4] == grp[2].segs[1][4] then own = own + 1 end
  end
  H.check(own == 4, own .. " of the star's 4 rays pair their own two faces alone")
  -- Each face is one plane: wherever one face alone covers a pixel, its
  -- slope is one of the star's 8, with no curve near the base or crease
  -- along a face.
  local paths = { shade = {}, lit = {} }
  for k = 1, 4 do
    paths.shade[k] = G.polyline(star.shade[k], true)
    paths.lit[k] = G.polyline(star.lit[k], true)
  end
  Paint.reset_resources()
  local spt = Paint.new({ backend = "pdf", gilt = "raster" })
  Raster.add(spt, "fill", paths.shade, { bevel = 0.8, tone = "shade" })
  Raster.add(spt, "fill", paths.lit, { bevel = 0.8 })
  local g = R.grid(0, 0, 100, 100, 0.25)
  local C, SX, SY, _, _, W = Relief.layers(g, spt.gilt_pending.shapes)
  local seen, kinds, n = {}, 0, 0
  for k = 1, g.n do
    if C[k] > 0.999 and W[k] > 0.999 then
      n = n + 1
      local key = string.format("%.6f %.6f", SX[k], SY[k])
      if not seen[key] then seen[key], kinds = true, kinds + 1 end
    end
  end
  H.check(n > 5000 and kinds == 8, string.format("the star's faces take %d slopes over %d pixels; 8 planes have 8", kinds, n))
end

-- Each ornament's gilt becomes images placed once each: every image is
-- registered once and drawn by exactly one Do, a single run of gold (the
-- swelled rule) makes one image, nothing is left pending, and no metal
-- ramp (vector gilt) is painted. Vector mode registers no images.
do
  for _, name in ipairs({ "swelled_rule", "compass_rose", "sun_crest", "rinceau", "cornerpiece", "fan", "wreath" }) do
    local k = Orn.kinds[name]
    local c = require("flora.gallery").cells[k.slot]
    for _, mode in ipairs({ "raster", "vector" }) do
      Paint.reset_resources()
      local pt = Paint.new({ backend = "pdf", gilt = mode })
      pt.gilt_dpi = 100
      Orn.draw(name, pt, Rng.new(3), { 0, 0, c[1], c[2] }, c[3])
      local xs = Paint.resources().xobjects
      local body = pt:body()
      if mode == "raster" then
        H.check(#xs >= 1, name .. ": raster gilt made no image")
        for _, x in ipairs(xs) do
          local _, n = body:gsub("/" .. x[1] .. " Do", "")
          H.check(n == 1, string.format("%s: image %s drawn %d times", name, x[1], n))
        end
        local _, dos = body:gsub(" Do ", "")
        H.check(dos == #xs, name .. ": Do count differs from images registered")
        H.check(not body:find("/Pattern cs"), name .. ": raster gilt painted a vector ramp")
        H.check(not pt.gilt_pending, name .. ": gilt left pending after the ornament")
        if name == "swelled_rule" then H.check(#xs == 1, "swelled_rule: " .. #xs .. " images, not 1") end
      else
        H.check(#xs == 0, name .. ": vector gilt made an image")
      end
    end
  end
end

-- Gold keeps its place in the painting order: ink painted after gold
-- inside an ornament lands after the gold's image, ink before it before.
do
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  pt.gilt_dpi = 100
  pt.gilding = true
  pt:fill(square, Paint.palette.ink, 1)
  pt:fill(square, Paint.palette.gold, 1)
  Gild.line(pt, { { { "m", 0, 0 }, { "l", 40, 40 } } }, 1)
  pt:stroke({ { "m", 0, 40 }, { "l", 40, 0 } }, Paint.palette.ink, 1)
  pt.gilding = false
  local body = pt:body()
  local ink1 = body:find("0.050 0.105 0.260 rg", 1, true)
  local img = body:find(" Do ", 1, true)
  local ink2 = body:find("0.050 0.105 0.260 RG", 1, true)
  H.check(ink1 and img and ink2 and ink1 < img and img < ink2, "raster gilt left its place in the painting order")
  H.check(#Paint.resources().xobjects == 1, "gold fill and gold line in one run made more than one image")
end

-- Settings: gilt and giltdpi parse and reject bad values, vector is the
-- default, and a page asked for raster gilt paints images.
do
  H.check(require("flora.tune").gilt == "raster", "tune.lua's default gilt is not raster")
  local t = Settings.parse("gilt=raster, giltdpi=300")
  H.check(t.gilt == "raster" and t.giltdpi == 300, "gilt settings lost")
  H.check(Settings.parse("giltenv=mirror").giltenv == "mirror", "giltenv lost")
  for _, bad in ipairs({ "gilt=gold", "giltdpi=20", "giltdpi=x", "giltenv=sky" }) do
    H.check(not pcall(Settings.parse, bad), "accepted bad setting " .. bad)
  end
  local spec = H.page(3)
  spec.layout, spec.gilt = "surround", "vector"
  Paint.reset_resources()
  local vec = Compose.page(spec)
  H.check(#Paint.resources().xobjects == 0 and not vec:body():find(" Do "), "a vector page made images")
  spec.gilt, spec.gilt_dpi = nil, 72
  Paint.reset_resources()
  local ras = Compose.page(spec)
  H.check(#Paint.resources().xobjects > 0 and ras:body():find(" Do "), "a page with the default gilt made no images")
  -- The pgf backend cannot place images and keeps vector gilt.
  Paint.reset_resources()
  local pgf = Paint.new({ backend = "pgf", gilt = "raster" })
  Orn.draw("swelled_rule", pgf, Rng.new(1), { 0, 0, 280, 46 })
  H.check(#Paint.resources().xobjects == 0, "the pgf backend made a raster image")
end

-- The site's scene carries each image as base64 RGBA, alpha after each
-- pixel's colour, padded as base64 is.
do
  local Pdf = require("flora.pdfout")
  local im = { w = 2, h = 1, rgb = "\1\2\3\4\5\6", alpha = "\255\128" }
  H.check(Pdf.rgba64(im) == "AQID/wQFBoA=", "base64 RGBA is " .. Pdf.rgba64(im))
  im = { w = 3, h = 1, rgb = "\1\2\3\4\5\6\7\8\9", alpha = "\255\128\10" }
  H.check(Pdf.rgba64(im) == "AQID/wQFBoAHCAkK", "base64 RGBA is " .. Pdf.rgba64(im))
end

-- Without zlib (Lua 5.4 in the browser) a page with raster gilt is still
-- ASCII, so it survives being passed to pdf.js as a JavaScript string;
-- with zlib (texlua) its images are Flate-compressed.
do
  local Pdf = require("flora.pdfout")
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  pt.gilt_dpi = 150
  Orn.draw("swelled_rule", pt, Rng.new(1), { 0, 0, 280, 46 })
  local z = rawget(_G, "zlib")
  _G.zlib = nil
  local plain = Pdf.encode(pt, 300, 60)
  _G.zlib = z
  H.check(not plain:find("[\128-\255]"), "a PDF written without zlib holds binary bytes")
  H.check(plain:find("/ASCIIHexDecode", 1, true) and plain:find("/XObject << /flimg1 ", 1, true), "the PDF does not carry its image")
  if z then H.check(Pdf.encode(pt, 300, 60):find("/FlateDecode", 1, true), "texlua did not compress the image") end
end

H.done("raster")
