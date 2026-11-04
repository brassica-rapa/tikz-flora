local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Settings = require("flora.settings")
local Orn = require("flora.ornaments")
local Gallery = require("flora.gallery")
local Rng = require("flora.rng")
local G = require("flora.geom")

-- Every kind paints something, and nothing past its box by more than its
-- reach, for several seeds (the gallery's cells; pendants without a cord,
-- which runs up out of the box by design).
do
  local cells = Gallery.layout(5)
  local seen = {}
  for _, c in ipairs(cells) do
    local b = c.box
    local kind = Orn.kinds[c.name]
    local slack = kind.reach * math.max(b[3] - b[1], b[4] - b[2]) + 0.5
    local n, worst = 0, 0
    Paint.reset_resources()
    local pt = Paint.new({ backend = "pdf" })
    pt.probe = function(x, y, pad)
      n = n + 1
      local out = math.max(b[1] - (x - pad), (x + pad) - b[3], b[2] - (y - pad), (y + pad) - b[4])
      worst = math.max(worst, out)
    end
    local o = {}
    for k, v in pairs(c.o or {}) do o[k] = v end
    o.cord = nil
    Orn.draw(kind, pt, Rng.new(c.seed * 131 + 7), b, o)
    H.check(n > 0, c.name .. " painted nothing")
    H.check(worst <= slack, string.format("%s (seed %d) paints %.1fpt past its box, reach allows %.1f", c.name, c.seed, worst, slack))
    seen[c.name] = true
  end
  for name in pairs(Orn.kinds) do H.check(seen[name], name .. " is missing from the gallery") end
end

-- Every registered kind has its weight in tune.lua, so the tuner and the
-- mixer show it.
do
  local Tune = require("flora.tune")
  for name in pairs(Orn.kinds) do
    H.check(Tune.ornaments[name] ~= nil, name .. " has no weight in tune.lua's ornaments")
  end
  for name in pairs(Tune.ornaments) do
    H.check(Orn.kinds[name] ~= nil, "tune.lua weighs " .. name .. ", which is not registered")
  end
end

-- Weights pick: 0 never, a lone weighted kind always, all 0 nothing.
do
  for _, slot in ipairs(Orn.slot_order) do
    local kinds = Orn.of(slot)
    local only = kinds[#kinds].name
    local w, none = {}, {}
    for _, k in ipairs(kinds) do w[k.name], none[k.name] = 0, 0 end
    w[only] = 2
    for seed = 1, 40 do
      local k = Orn.pick(Rng.new(seed), slot, w)
      H.check(k and k.name == only, string.format("%s: picked %s with only %s weighted", slot, k and k.name or "nothing", only))
      H.check(Orn.pick(Rng.new(seed), slot, none) == nil, slot .. ": picked a kind with every weight 0")
    end
  end
  -- Default weights reach every kind of a slot.
  local hit = {}
  for seed = 1, 400 do hit[Orn.pick(Rng.new(seed), "cartouche").name] = true end
  for _, k in ipairs(Orn.of("cartouche")) do H.check(hit[k.name], k.name .. " never picked in 400 seeds") end
end

-- Settings: ornaments={...} parses, and unknown kinds or bad weights fail
-- with the key's name.
do
  local t = Settings.parse("ornaments={moon=2, night=0, cul_de_lampe=1.5}")
  H.check(t.ornaments.moon == 2 and t.ornaments.night == 0 and t.ornaments.cul_de_lampe == 1.5, "ornaments did not parse")
  local ok, err = pcall(Settings.parse, "ornaments={comet=1}")
  H.check(not ok and err:find("no ornament \"comet\""), "an unknown ornament was accepted: " .. tostring(err))
  ok, err = pcall(Settings.parse, "ornaments={moon=11}")
  H.check(not ok and err:find("moon needs a weight"), "a weight of 11 was accepted: " .. tostring(err))
end

local function page(seed, ornaments, spec)
  local s = spec or H.page(seed)
  s.seed, s.ornaments = seed, ornaments
  Paint.reset_resources()
  return Compose.page(s)
end

-- A page's ornament choices draw from streams of their own: changing the
-- cartouche's kind leaves every other paint operation where it was, so the
-- pages differ only inside the cartouche's box.
do
  for seed = 1, 3 do
    local a = page(seed, { night = 1, sun = 0, moon = 0, constellation = 0, planet = 0, armillary = 0, scrolled = 0, strapwork = 0 })
    local b = page(seed, { night = 0, sun = 1, moon = 0, constellation = 0, planet = 0, armillary = 0, scrolled = 0, strapwork = 0 })
    H.check((a.panel == nil) == (b.panel == nil), "the cartouche kind moved the cartouche")
    if a.panel then
      H.check(a.panel[1] == b.panel[1] and a.panel[2] == b.panel[2], "the cartouche kind moved the cartouche")
      H.check(a:code() ~= b:code(), "night and sun cartouches painted the same")
    end
    H.check(a.coverage == b.coverage, "the cartouche kind changed the plant's coverage")
  end
  -- With every cartouche kind at 0 there is no cartouche.
  local zero = {}
  for _, k in ipairs(Orn.of("cartouche")) do zero[k.name] = 0 end
  for seed = 1, 4 do H.check(page(seed, zero).panel == nil, "a cartouche with every kind weighted 0") end
end

-- The larger gilt: with the newer kinds at 0 only the reference's appear,
-- placed exactly as before; with only a newer kind, every one is that kind.
do
  local classic = { cross = true, rosette = true, dotted = true, lozenge = true }
  local old = { gilt_star = 0, gilt_crescent = 0, gilt_trefoil = 0 }
  local stars = { gilt_cross = 0, gilt_rosette = 0, gilt_dotted = 0, gilt_lozenge = 0, gilt_crescent = 0, gilt_trefoil = 0, gilt_star = 1 }
  local big = 0
  for seed = 1, 3 do
    local a, mixed, s = page(seed, old).sparkles, page(seed).sparkles, page(seed, stars).sparkles
    for i, it in ipairs(a) do
      if it[3] >= 4.2 then H.check(classic[it[4]], "a newer gilt kind with its weight at 0: " .. it[4]) end
      local m = mixed[i]
      H.check(m and m[1] == it[1] and m[2] == it[2], "the newer gilt kinds moved the sparkles")
    end
    for _, it in ipairs(s) do
      if it[3] >= 4.2 then
        big = big + 1
        H.check(it[4] == "star5", "gilt_star alone, but a " .. it[4])
      end
    end
  end
  H.check(big > 0, "no larger gilt with only gilt_star weighted")
end

-- The title page's furniture: each piece stays off the text, and the
-- crowning plants stay out of the boxes kept for it.
do
  local function title_spec(seed)
    return {
      width = 595.28, height = 841.89, seed = seed, layout = "title",
      text = { x0 = 91, y0 = 114, x1 = 506, y1 = 703 },
      lines = {
        { x0 = 222, x1 = 375, y0 = 685, y1 = 703 },
        { x0 = 196, x1 = 401, y0 = 656, y1 = 667 },
        { x0 = 162, x1 = 436, y0 = 463, y1 = 473 },
        { x0 = 162, x1 = 436, y0 = 451, y1 = 461 },
        { x0 = 370, x1 = 436, y0 = 425, y1 = 433 },
      },
    }
  end
  local slots = {}
  for seed = 1, 4 do
    local spec = title_spec(seed)
    local lines = spec.lines
    local Frames = require("flora.frames")
    local _, keep = require("flora.orn_title").plan(spec, Frames.top_block(spec), 60)
    local on_text, in_keep = 0, 0
    spec.probe = function(x, y, pad, tag)
      if tag == "title" then
        for _, l in ipairs(lines) do
          if x + pad > l.x0 and x - pad < l.x1 and y + pad > l.y0 and y - pad < l.y1 then on_text = on_text + 1 end
        end
      else
        for _, k in ipairs(keep) do
          if x > k[1] and x < k[3] and y > k[2] and y < k[4] then in_keep = in_keep + 1 end
        end
      end
    end
    local pt = page(seed, nil, spec)
    for _, p in ipairs(pt.title) do slots[p.slot] = (slots[p.slot] or 0) + 1 end
    H.check(on_text == 0, string.format("seed %d: title furniture paints %d points on text", seed, on_text))
    H.check(in_keep == 0, string.format("seed %d: the crown paints %d points in the furniture's boxes", seed, in_keep))
    H.check(#keep >= 2, "the flourish and tailpiece kept no room")
  end
  for _, slot in ipairs({ "crest", "flourish", "tailpiece", "corner" }) do
    H.check((slots[slot] or 0) >= 4, slot .. " missing from some title pages")
  end
  -- A page that grows still paints no furniture until the plants are done.
  local spec = title_spec(1)
  spec.grow = 0.5
  local n = 0
  spec.probe = function(_, _, _, tag) if tag == "title" then n = n + 1 end end
  page(1, nil, spec)
  H.check(n == 0, "title furniture painted on a page half grown")
end

-- The title page's two corner pieces are one design mirrored: every point
-- painted in the left corner has its mirror image in the right one, for
-- every corner kind (a kind drawing from two streams breaks this). Gilt is
-- painted flat here: its light falls from the page's upper left, which
-- rightly differs between the corners.
do
  local Title = require("flora.orn_title")
  local W = 600
  for _, k in ipairs(Orn.of("corner")) do
    for seed = 1, 3 do
      local left, right = {}, {}
      Paint.reset_resources()
      local pt = Paint.new({ backend = "pdf" })
      pt.flat_gilt = true
      pt.probe = function(x, y)
        local into = x < W / 2 and left or right
        into[#into + 1] = { x < W / 2 and x or W - x, y }
      end
      local plan = {
        { slot = "corner", kind = k, box = { 16, 16, 88, 88 }, o = { flip = { 1, 1 } } },
        { slot = "corner", kind = k, box = { W - 88, 16, W - 16, 88 }, o = { flip = { -1, 1 } } },
      }
      Title.paint(pt, { seed = seed, width = W }, plan)
      -- Each point has a mirror within 0.4pt (float noise can add a
      -- resample point to a curve, never move a feature), both ways.
      local function unmatched(from, to)
        local grid = {}
        for _, q in ipairs(to) do
          local key = math.floor(q[1]) .. "," .. math.floor(q[2])
          grid[key] = grid[key] or {}
          table.insert(grid[key], q)
        end
        local n = 0
        for _, q in ipairs(from) do
          local hit = false
          for gx = math.floor(q[1]) - 1, math.floor(q[1]) + 1 do
            for gy = math.floor(q[2]) - 1, math.floor(q[2]) + 1 do
              for _, r in ipairs(grid[gx .. "," .. gy] or {}) do
                if math.abs(r[1] - q[1]) < 0.4 and math.abs(r[2] - q[2]) < 0.4 then hit = true end
              end
            end
          end
          if not hit then n = n + 1 end
        end
        return n
      end
      local missing = unmatched(left, right) + unmatched(right, left)
      H.check(#left > 0 and missing == 0, string.format("%s (seed %d): %d left-corner points have no mirror on the right", k.name, seed, missing))
    end
  end
end

-- Gilt is lit from the page's upper left whatever frame it is drawn in,
-- in a plain frame and a mirrored one: the vector metal ramp's lit end
-- lies up and to the left of its dark end, and raster gold is brighter
-- on its upper-left half.
do
  local Gild = require("flora.orn_gild")
  for _, fx in ipairs({ 1, -1 }) do
    Paint.reset_resources()
    local pt = Paint.new({ backend = "pdf", gilt = "vector" })
    pt:frame(function(x, y) return 300 + fx * (x - 300), y end)
    Gild.fill(pt, { G.polyline({ { 100, 100 }, { 140, 100 }, { 140, 140 }, { 100, 140 } }, true) })
    local pats = Paint.resources().patterns
    local c = pats[#pats].coords
    H.check(c[1] < c[3] and c[2] > c[4], string.format("flip %d: gilt lit from (%.0f, %.0f) toward (%.0f, %.0f)", fx, c[1], c[2], c[3], c[4]))
    Paint.reset_resources()
    pt = Paint.new({ backend = "pdf", gilt = "raster" })
    pt.gilt_dpi = 150
    pt:frame(function(x, y) return 300 + fx * (x - 300), y end)
    pt.gilding = true
    Gild.fill(pt, { { { "o", 120, 120, 20 } } })
    pt.gilding = false
    local im = require("flora.orn_raster").render(pt.gilt_pending, 150)
    local lit, far = 0, 0
    for row = 1, im.h do
      for col = 1, im.w do
        local k = (row - 1) * im.w + col
        if im.alpha:byte(k) == 255 then
          local l = im.rgb:byte(3 * k - 2) + im.rgb:byte(3 * k - 1) + im.rgb:byte(3 * k)
          if col + row < (im.w + im.h) / 2 - 2 then lit = lit + l elseif col + row > (im.w + im.h) / 2 + 2 then far = far + l end
        end
      end
    end
    H.check(lit > far * 1.1, string.format("flip %d: raster gilt is not lit from the upper left", fx))
  end
end

-- Gold paints as gilt (vector: a shaded ramp; raster, the default: an
-- image) inside an ornament and flat outside one, and drawing an ornament
-- leaves the painter as it found it.
do
  local square = G.polyline({ { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } }, true)
  Paint.reset_resources()
  local ras = Paint.new({ backend = "pdf" })
  ras.gilt_dpi = 100
  ras:fill(square, Paint.palette.gold, 0.9)
  H.check(not ras:body():find(" Do "), "gold outside an ornament was raster gilt")
  Orn.draw("swelled_rule", ras, Rng.new(1), { 0, 0, 280, 46 })
  H.check(ras:body():find(" Do ") and not ras.gilt_pending, "a gilt ornament placed no raster gold by default")
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "vector" })
  pt:fill(square, Paint.palette.gold, 0.9)
  H.check(not pt:body():find("Pattern"), "gold outside an ornament was gilt")
  Orn.draw("swelled_rule", pt, Rng.new(1), { 0, 0, 280, 46 })
  H.check(pt:body():find("/Pattern cs"), "a gilt ornament painted no metal ramp")
  H.check(not pt.gilding, "the painter is left gilding after an ornament")
  pt.out = {}
  pt:fill(square, Paint.palette.gold, 0.4)
  pt:fill(square, Paint.palette.copper, 0.9, { blend = "multiply" })
  H.check(not pt:body():find("Pattern"), "a gold wash or copper ink was gilt")
end

H.done("ornaments")
