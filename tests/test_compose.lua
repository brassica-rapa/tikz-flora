local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Layout = require("flora.layout")
local Rng = require("flora.rng")

-- Nothing painted may land on measured text. The probe sees every path
-- vertex (with its radius for dots), so a leaf or bloom that grows over a
-- line is caught here.
local function overlaps(spec)
  local bad, first = 0, nil
  spec.probe = function(x, y, r)
    for _, l in ipairs(spec.lines) do
      if x + r > l.x0 + 1 and x - r < l.x1 - 1 and y + r > l.y0 + 1 and y - r < l.y1 - 1 then
        bad = bad + 1
        first = first or string.format("(%.1f, %.1f) in line %.1f..%.1f x %.1f..%.1f",
          x, y, l.x0, l.x1, l.y0, l.y1)
        return
      end
    end
  end
  Compose.page(spec)
  return bad, first
end

for seed = 1, 6 do
  local full = H.page(seed, nil, { [12] = true, [13] = true, [14] = true })
  local n, where = overlaps(full)
  H.check(n == 0, string.format("seed %d full page: %d points on text, first %s", seed, n, where))
  local short = H.page(seed, 420)
  n, where = overlaps(short)
  H.check(n == 0, string.format("seed %d short page: %d points on text, first %s", seed, n, where))
end

-- A seed reproduces its page exactly; another seed gives a different page.
do
  local Paint = require("flora.paint")
  local function render(seed)
    Paint.reset_resources()
    return Compose.page(H.page(seed)):code()
  end
  local a, b, c = render(7), render(7), render(8)
  H.check(a == b, "same seed produced different output")
  H.check(a ~= c, "different seeds produced identical output")
end

-- The excursion strand appears only when the text leaves real room, and
-- stays below the last line.
do
  local full = H.page(3)
  H.check(Layout.excursion(Rng.new(1), full, { 60, 40 }) == nil, "excursion on a full page")
  local short = H.page(3, 420)
  local ex = Layout.excursion(Rng.new(1), short, { 60, 40 })
  H.check(ex ~= nil, "no excursion on a half-empty page")
  if ex then
    local lowest = math.huge
    for _, l in ipairs(short.lines) do
      if l.x0 >= short.text.x0 and l.y0 > short.text.y0 then lowest = math.min(lowest, l.y0) end
    end
    for _, p in ipairs(ex.pts) do
      H.check(p[2] < lowest, string.format("excursion point %.1f reaches line at %.1f", p[2], lowest))
    end
  end
end

-- Indented lines open room beside them; full-width lines do not.
do
  local spec = H.page(1, nil, { [12] = true })
  local g = Layout.region(spec)
  local ind = spec.lines[12]
  local full = spec.lines[20]
  local ymid = (ind.y0 + ind.y1) / 2
  H.check(g:open_at(spec.text.x0 + 8, ymid), "no room opened beside an indented line")
  H.check(not g:open_at(spec.text.x0 + 8, (full.y0 + full.y1) / 2), "room opened beside a full line")
end

-- Stems flow: along every strand, runner and flourish, consecutive segments
-- turn by less than 20 degrees, so no stem shows a corner. Curvature-built
-- volutes may wind tightly, but never in a single sharp step.
do
  local G = require("flora.geom")
  local S = require("flora.sprig")
  local function max_turn(pts)
    local worst, prev = 0, nil
    for i = 2, #pts do
      if G.dist(pts[i - 1], pts[i]) > 0.02 then
        local a = G.angle(pts[i - 1], pts[i])
        if prev then worst = math.max(worst, math.abs(G.turn(a, prev))) end
        prev = a
      end
    end
    return worst
  end
  local limit = math.rad(20)
  for seed = 1, 4 do
    local spec = H.page(seed, 420)
    local g, m = Layout.region(spec)
    local hero = { m.x0 + (m.x1 - m.x0) * 0.5, 700, 70 }
    local strands, root = Layout.strands(Rng.new(seed), m, hero, spec.width)
    local all = { table.unpack(strands) }
    for _, r in ipairs(Layout.runners(Rng.new(seed), m, root, spec.width, 16)) do all[#all + 1] = r end
    local ex = Layout.excursion(Rng.new(seed), spec, root)
    if ex then all[#all + 1] = ex end
    for k, s in ipairs(all) do
      local t = max_turn(s.pts)
      H.check(t < limit, string.format("seed %d stem %d turns %.0f degrees in one step", seed, k, math.deg(t)))
    end
  end
  for _, len in ipairs({ 14, 30, 60 }) do
    local t1 = max_turn(S.tendril({ 0, 0 }, 0, len, 1))
    local t2 = max_turn(S.flourish({ 0, 0 }, 0, len, -1))
    H.check(t1 < limit and t2 < limit, string.format("curl of length %d has a corner (%.0f, %.0f degrees)",
      len, math.deg(t1), math.deg(t2)))
  end
  local link = G.link({ 0, 0 }, 0, { 30, 30 }, math.pi / 2)
  H.check(max_turn(link) < limit, "link has a corner")
  H.check(math.abs(G.turn(G.angle(link[1], link[2]), 0)) < 0.1, "link does not leave along its start heading")
end

-- The border has a line of action: the main strand swings well in from the
-- outer margin and back, rather than rising as a straight column, and the
-- star cartouche finds room in a quiet stretch beside it.
do
  local G = require("flora.geom")
  local with_panel = 0
  for seed = 1, 6 do
    local spec = H.page(seed)
    local g, m = Layout.region(spec)
    local mw = m.x1 - m.x0
    local hero = { m.x0 + mw * 0.5, spec.header_y - 40, 70 }
    local gest = Layout.gesture(Rng.new(seed), m, hero)
    local strands = Layout.strands(Rng.new(seed), m, hero, spec.width, gest)
    local lo, hi = math.huge, -math.huge
    for _, p in ipairs(strands[1].pts) do
      if p[2] > m.y0 + mw and p[2] < hero[2] - hero[3] * 2.5 then
        lo, hi = math.min(lo, p[1]), math.max(hi, p[1])
      end
    end
    -- The swing follows the configured bow reach; a straight column (no
    -- bows) fails at any reach.
    local reach = require("flora.tune").gesture.bow_amp[1] * mw
    H.check(hi - lo > 0.6 * reach, string.format("seed %d main strand swings only %.0f pt for a %.0f pt bow", seed, hi - lo, reach))
    local peak, calm = gest.density(gest.edge + gest.bows[1].amp * 0.7, gest.bows[1].y), gest.density(gest.edge, gest.quiet[1])
    H.check(peak > 1.6 * calm, string.format("seed %d density does not modulate (%.2f vs %.2f)", seed, peak, calm))
    if Compose.page(H.page(seed)).panel then with_panel = with_panel + 1 end
  end
  H.check(with_panel >= 5, string.format("cartouche placed on only %d of 6 pages", with_panel))
end

-- Most pages hold a large ghost bloom low in the outer margin: centred in
-- the margin's width, above the foot and below the lowest fifth of the
-- text block, and clear of the text.
do
  local n = 0
  for seed = 1, 8 do
    local spec = H.page(seed)
    local gh = Compose.page(spec).ghost
    if gh then
      n = n + 1
      local x, y, r = gh[1], gh[2], gh[3]
      local t = spec.text
      H.check(x + r * 0.9 <= t.x0, string.format("seed %d: ghost bloom reaches the text (%.0f + %.0f)", seed, x, r))
      H.check(y > t.y0 and y < t.y0 + (t.y1 - t.y0) * 0.2, string.format("seed %d: ghost bloom at y %.0f, not low in the margin", seed, y))
      H.check(r >= 25, string.format("seed %d: ghost bloom only %.0f pt", seed, r))
    end
  end
  H.check(n >= 5, string.format("ghost bloom on only %d of 8 pages", n))
end

-- Every layout tells spec.progress how far the page has got: a rising
-- list, by at least 0.01 a step, ending in exactly 1; the hook changes
-- nothing painted.
do
  local Paint = require("flora.paint")
  for _, layout in ipairs({ "left", "right", "centered", "split", "title", "surround", "flank", "wreath", "bouquet", "scrollwork" }) do
    local spec = H.page(3)
    spec.layout = layout
    Paint.reset_resources()
    local plain = Compose.page(spec):code()
    local sent = {}
    spec.progress = function(f) sent[#sent + 1] = f end
    Paint.reset_resources()
    local told = Compose.page(spec):code()
    H.check(told == plain, layout .. ": the progress hook changes the page")
    H.check(#sent >= 20, string.format("%s: only %d progress values", layout, #sent))
    H.check(sent[#sent] == 1, string.format("%s: progress ends at %s", layout, tostring(sent[#sent])))
    for k = 2, #sent do
      local step = sent[k] - sent[k - 1]
      H.check(step >= 0.01 - 1e-12 or (sent[k] == 1 and step > 0),
        string.format("%s: progress %d goes %.4f -> %.4f", layout, k, sent[k - 1], sent[k]))
    end
  end
end

H.done("compose")
