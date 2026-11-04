-- The title layouts after engraved title pages (frames.lua): flank,
-- wreath, bouquet and scrollwork; the oval their curved frames follow
-- (oval.lua); and \floraletters' options (letters.lua).
local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Frames = require("flora.frames")
local Oval = require("flora.oval")
local Ribbon = require("flora.orn_ribbon")
local Settings = require("flora.settings")
local Letters = require("flora.letters")

local W, PH = 595.28, 841.89
local LAYOUTS = { "flank", "wreath", "bouquet", "scrollwork" }

-- A title page: 2.5 cm margins, a three-line title in the middle, an
-- author's line under it and an imprint at the foot, under the middle of
-- the page.
local function title_page(seed)
  local title = {
    { x0 = 220, x1 = 375, y0 = 560, y1 = 600 },
    { x0 = 250, x1 = 345, y0 = 520, y1 = 540 },
    { x0 = 200, x1 = 395, y0 = 470, y1 = 500 },
  }
  local imprint = { x0 = 255, x1 = 340, y0 = 72, y1 = 80 }
  -- An author's line under the title, in the bouquet's reach.
  local author = { x0 = 245, x1 = 350, y0 = 380, y1 = 392 }
  local lines = { title[1], title[2], title[3], author, imprint }
  return {
    width = W, height = PH, seed = seed, page = 1,
    text = { x0 = 71, y0 = 71, x1 = 524, y1 = 771 },
    lines = lines, title = { x0 = 200, y0 = 470, x1 = 395, y1 = 600 },
  }, title, imprint, author
end

-- Every painted point of a page as {x, y, r, tag}, with the frame being
-- painted when it was (nil outside the frames).
local function points(spec)
  local pts, label = {}, nil
  spec.on_frame = function(f) label = f.label end
  spec.probe = function(x, y, r, tag)
    -- Only plants paint inside frames; "under", "over" and "title" are the
    -- layout's own pieces.
    local plant = tag ~= "under" and tag ~= "over" and tag ~= "title"
    pts[#pts + 1] = { x, y, r or 0, tag, plant and label or nil }
  end
  Paint.reset_resources()
  local pt = Compose.page(spec)
  return pts, pt
end

local function on_box(p, b, pad)
  pad = pad or 1
  return p[1] + p[3] > b.x0 + pad and p[1] - p[3] < b.x1 - pad and p[2] + p[3] > b.y0 + pad and p[2] - p[3] < b.y1 - pad
end

-- Each layout's page, painted once with its points recorded, on its own
-- seed; the checks below share them.
local pages = {}
for i, lay in ipairs(LAYOUTS) do
  local spec, title, imprint, author = title_page(i)
  spec.layout = lay
  local pts, pt = points(spec)
  pages[lay] = { spec = spec, title = title, imprint = imprint, author = author, pts = pts, pt = pt }
end

-- No title layout paints on the page's lines; the bouquet's plants grow
-- behind its title lines, which its ribbons cover, but never on the
-- author's line or the imprint. A runner rising by the page's middle
-- would cross the imprint.
for _, lay in ipairs(LAYOUTS) do
  local pg = pages[lay]
  local check = lay == "bouquet" and { pg.author, pg.imprint } or pg.spec.lines
  local where
  for _, p in ipairs(pg.pts) do
    for _, l in ipairs(check) do
      if not where and on_box(p, l) then where = string.format("(%.1f, %.1f) %s", p[1], p[2], tostring(p[4])) end
    end
  end
  H.check(not where, string.format("%s paints on text at %s", lay, tostring(where)))
  H.check(#pg.pts > 2000, string.format("%s paints only %d points", lay, #pg.pts))
end

-- A page on a curved frame reproduces.
do
  local spec = title_page(7)
  spec.layout = "wreath"
  Paint.reset_resources()
  local a = Compose.page(spec):code()
  Paint.reset_resources()
  H.check(Compose.page(spec):code() == a, "wreath does not reproduce")
end

-- The outer-corner runner is left out when it would cross text, and only
-- then.
do
  local Layout = require("flora.layout")
  local Rng = require("flora.rng")
  local spec = { width = 300, height = 842, text = { x0 = 190, y0 = 71, x1 = 300, y1 = 771 }, lines = {} }
  local g, m = Layout.region(spec)
  local r = Layout.runners(Rng.new(1), m, { 190, 24 }, 300, 16, g)
  H.check(#r == 1, "a runner clear of text was left out")
  local mid = r[1].pts[math.floor(#r[1].pts * 0.6)]
  spec.lines = { { x0 = mid[1] - 20, y0 = mid[2] - 4, x1 = mid[1] + 20, y1 = mid[2] + 4 } }
  g, m = Layout.region(spec)
  H.check(#Layout.runners(Rng.new(1), m, { 190, 24 }, 300, 16, g) == 0, "a runner crossing a line was kept")
end

-- Every new layout parses, and a wrong one names them all.
do
  for _, lay in ipairs(Frames.order) do
    H.check(Settings.parse("layout=" .. lay).layout == lay, "layout=" .. lay .. " does not parse")
  end
  local ok, err = pcall(Settings.parse, "layout=oval")
  H.check(not ok and tostring(err):find("scrollwork", 1, true), "a wrong layout's error does not list scrollwork: " .. tostring(err))
end

-- The oval's maps: a frame point goes to the page and back, on both
-- sides, and frame x grows inward.
do
  local ov = Oval.new(W / 2, 430, 240, 300)
  H.check(math.abs(ov.len - 2 * math.pi * math.sqrt((240 ^ 2 + 300 ^ 2) / 2)) < ov.len * 0.01, "oval perimeter is off")
  for _, mirror in ipairs({ false, true }) do
    local fn, inv = ov:maps(-20, 50, mirror)
    for _, q in ipairs({ { 10, 0 }, { 50, 100 }, { 90, 400 }, { 30, ov.len / 2 - 30 }, { 70, -10 } }) do
      local px, py = fn(q[1], q[2])
      local x, y = inv(px, py)
      H.check(math.abs(x - q[1]) < 1e-6 and math.abs(y - q[2]) < 1e-6,
        string.format("oval map (mirror %s) sends (%g, %g) back as (%.4f, %.4f)", tostring(mirror), q[1], q[2], x, y))
    end
    -- Inward: further along frame x is nearer the centre.
    local ax, ay = fn(20, 300)
    local bx, by = fn(80, 300)
    local da = (ax - ov.cx) ^ 2 / ov.a ^ 2 + (ay - ov.cy) ^ 2 / ov.b ^ 2
    local db = (bx - ov.cx) ^ 2 / ov.a ^ 2 + (by - ov.cy) ^ 2 / ov.b ^ 2
    H.check(da > 1 and db < 1, "frame x does not run from outside the oval to inside it")
    -- The left frame climbs the left side, the right one the right.
    local mx = fn(50, ov.len / 4)
    H.check(mirror and mx > ov.cx or not mirror and mx < ov.cx, "frame is on the wrong side")
  end
  -- A point past the foot maps below the frame, not past its top.
  local _, inv = ov:maps(0, 50, false)
  local x, y = ov:point(ov:theta(ov.len - 30))
  local _, fy = inv(x, y)
  H.check(fy < 0 and fy > -40, string.format("a point past the foot maps to frame y %.1f", fy))
end

-- Wreath: each plant keeps to its own half of the oval, and inside the
-- band round it.
do
  local pg = pages.wreath
  local ov = Frames.of(pg.spec).oval
  local pts = pg.pts
  local stray = {}
  for _, p in ipairs(pts) do
    local side = p[5]
    if side == "left" and p[1] > W / 2 + 70 or side == "right" and p[1] < W / 2 - 70 then
      stray[side] = (stray[side] or 0) + 1
    end
  end
  H.check(not stray.left and not stray.right,
    string.format("wreath plants stray to the other side (left %d, right %d)", stray.left or 0, stray.right or 0))
  H.check(ov.a > 200 and ov.b <= ov.a * 1.3 + 1e-6, "wreath oval is not page-wide or is taller than 1.3 of its width")
end

-- An oval keeps to the room between the lines round the title.
do
  local spec, _, imprint = title_page(1)
  local ov, mw, xc = Frames.oval(spec, spec.title)
  H.check(ov.cy - ov.b - xc >= imprint.y1, string.format("oval's band (%.1f) reaches the imprint (%.1f)", ov.cy - ov.b - xc, imprint.y1))
  H.check(mw > 0, "no band")
end

-- Flank: the plants keep to the side margins, out of the contents'
-- column, and the foot piece sits between their roots, clear of the
-- lines.
do
  local spec = pages.flank.spec
  local fs = Frames.of(spec)
  local piece = fs.title and fs.title[1]
  H.check(piece, "flank has no foot piece")
  local b = piece.box
  H.check(math.abs((b[1] + b[3]) / 2 - W / 2) < 1e-6, "foot piece is not centred")
  for _, l in ipairs(spec.lines) do
    H.check(not (b[3] > l.x0 and b[1] < l.x1 and b[4] > l.y0 and b[2] < l.y1), "foot piece overlaps a line")
  end
  local pts = pages.flank.pts
  local inside = 0
  local half = 395 - W / 2 + 12
  for _, p in ipairs(pts) do
    if p[5] and math.abs(p[1] - W / 2) < half - 14 and p[2] > spec.text.y0 + 14 then inside = inside + 1 end
  end
  H.check(inside == 0, string.format("flank plants paint %d points in the contents' column", inside))
end

-- Bouquet: one ribbon per title line, whose face holds the line; the
-- plants stay inside the bouquet's outline; the right half stands lower.
do
  local spec, title = pages.bouquet.spec, pages.bouquet.title
  local fs = Frames.of(spec)
  H.check(#Frames.lines_in(spec, spec.title) == #title, "bouquet does not find every title line")
  for i, l in ipairs(title) do
    local r = Ribbon.shape(l, i % 2 == 1 and -1 or 1)
    local f = r.face
    H.check(f[1][1] <= l.x0 - 4 and f[2][1] >= l.x1 + 4 and f[1][2] <= l.y0 - 3 and f[3][2] >= l.y1 + 3,
      "ribbon face does not hold its line")
  end
  H.check(fs[2].spec.height < fs[1].spec.height, "bouquet halves stand level")
  local mw = fs[1].spec.text.x0 - 4 - 9
  local base, h = fs[1].map[6], fs[1].spec.height
  local pts = pages.bouquet.pts
  local out, low = 0, 0
  for _, p in ipairs(pts) do
    if p[5] then
      local dx = math.abs(p[1] - W / 2)
      if dx > mw * 1.25 + 30 then out = out + 1 end
      -- Its outline narrows to the tie: the lowest fifth is under half its
      -- width (the tie's bow, painted over the plants, is not counted).
      if p[2] < base + h * 0.2 and dx > mw * 0.5 + 20 then low = low + 1 end
    end
  end
  H.check(out == 0, string.format("bouquet plants paint %d points outside the bouquet", out))
  H.check(low == 0, string.format("bouquet plants paint %d points wide of its narrow foot", low))
end

-- Scrollwork: the band is painted first, under the plants, and the plants
-- keep out of the head and foot pieces' boxes.
do
  local spec = pages.scrollwork.spec
  local plan = Frames.of(spec).scrollwork
  local pts, pt = pages.scrollwork.pts, pages.scrollwork.pt
  H.check(pt.boxes[1] and pt.boxes[1].tag == "under", "scrollwork band is not painted first")
  local last = pt.boxes[#pt.boxes]
  H.check(last and last.tag == "over", "scrollwork head and foot are not painted last")
  local hits = 0
  for _, p in ipairs(pts) do
    if p[5] then
      for _, k in ipairs({ plan.head, plan.foot }) do
        if on_box(p, { x0 = k[1], y0 = k[2], x1 = k[3], y1 = k[4] }, 2) then hits = hits + 1 end
      end
    end
  end
  H.check(hits == 0, string.format("scrollwork plants paint %d points in the head or foot", hits))
end

-- \floraletters' options are checked.
do
  local o = Letters.options("")
  H.check(o.style == "shaded" and o.arch == 0 and o.ink == nil, "lettering defaults changed")
  o = Letters.options("style=engraved, arch=-30, ink=momiji")
  H.check(o.style == "engraved" and o.arch == -30 and o.ink == "momiji", "lettering options did not parse")
  H.check(Letters.options("ink=black").ink == nil, "ink=black is not the default black")
  for _, bad in ipairs({ "style=gothic", "arch=200", "arch=wide", "ink=plaid", "size=3", "engraved" }) do
    H.check(not Letters.options(bad), "lettering accepted \"" .. bad .. "\"")
  end
end

H.done("titles")
