-- The painted songbird (animals=painted): a perched bird made of shapes
-- joined in a signed-distance field (sdf.lua) rather than one traced outline.
-- Head, neck and body are a smooth union; the tail is individual feathers
-- painted behind the body, darker and with rounded or pointed tips; the wing
-- is one merged shape of coverts and primaries with feather lines; the
-- belly is its own colour (the body's shape cut by a belly ellipse), the back
-- is the `blooms` ink and the belly the `leaves` ink. Genes (build, tail,
-- wing, beak, eye) come from the generator's random stream, so each bird
-- differs. (x, y) is the twig tip the feet grip; `dir` is 1 or -1.

local S = require("flora.sdf")
local G = require("flora.geom")
local W = require("flora.wash")
local Paint = require("flora.paint")
local Color = require("flora.color")
local pal = Paint.palette
local MULT = { blend = "multiply" }
local cos, sin, pi, abs, max, min = math.cos, math.sin, math.pi, math.abs, math.max, math.min

local function genes(rng)
  return {
    body_rx = rng:range(9.5, 12), body_ry = rng:range(6.5, 8.2),
    head = rng:range(4.2, 5.4), neck = rng:range(0.0, 2.5),
    blend = rng:range(2.5, 6.0), belly = rng:range(0, 2.0),
    tail = rng:range(20, 30), tail_w = rng:range(2.3, 3.1), feathers = rng:int(4, 6),
    fan = rng:range(0.07, 0.17), tail_ang = rng:range(-0.25, 1.0), graduated = rng:range(0.0, 0.25),
    tip = rng:pick({ "round", "point", "round" }),
    wing = rng:range(0.9, 1.15), primaries = rng:int(3, 5),
    belly_size = rng:range(0.62, 0.8),
    -- beak
    beak_len = rng:range(2.6, 4.4), beak_root = rng:range(0.34, 0.55), beak_droop = rng:range(0.0, 0.1),
    beak_arch = rng:range(0.0, 0.05), beak_hook = rng:range(0.0, 0.08),
    beak_col = rng:pick({ "gold", "gold", "horn", "orange" }),
    -- eye
    eye_r = rng:range(1.0, 1.35),
  }
end

local function body_field(g)
  local hx, hy = 10.5 + g.neck * 0.4, 9.5 + g.neck
  local trunk = S.union({
    S.ellipse(-1, 3.5, g.body_rx, g.body_ry, 0.12),
    S.circle(2, 2.2 - g.belly * 0.2, g.body_ry * 0.95 + g.belly * 0.3),
    S.circle(hx, hy, g.head),
    S.capsule(5, 5.5, hx - 1, hy - 1.5, g.body_ry * 0.75, g.head * 0.9),
    S.capsule(-5, 4.3, -10, 4.6, 3.6, 1.9),
  }, g.blend)
  return trunk, { hx = hx, hy = hy }
end

-- The belly colour's shape at inset t: the body cut by a belly ellipse that
-- shrinks by t. The body's own edge never moves, so only the upper edge fades.
local function belly_field(g, body, t)
  local b = S.ellipse(2.5, -1.5, g.body_rx * 0.95, g.body_ry * g.belly_size * 1.5, 0.1)
  return function(x, y) return max(body(x, y), b(x, y) + t) end
end

local ROOT = { -8.5, 4.6 }

local function feather(x1, y1, x2, y2, w, tip)
  local rb = tip == "point" and w * 0.25 or w * 0.8
  local pad = w + 2
  local box = { min(x1, x2) - pad, min(y1, y2) - pad, max(x1, x2) + pad, max(y1, y2) + pad }
  return S.outline(S.capsule(x1, y1, x2, y2, w, rb), box, 0.2, 44)
end

local function hair(pt, pts, w, op)
  pt:stroke(G.polyline(pts), pal.ink, w, op or 0.85, MULT)
end

local function paint_feather(pt, rng, map, at, poly, root, tip_pt, size, strength, sc)
  W.wash(pt, map(poly), { rng = rng, size = size, ramp = "vivid", part = "blooms",
    axis = { at(root), at(tip_pt) }, pigment = pal.deep, pool = pal.deep, strength = strength,
    simple = true, lost = 0.12, outline = 0.7, outline_w = 0.3 * sc, grain = 0.1 })
end

local function paint_tail(pt, rng, g, map, at, sc)
  local n = g.feathers
  local list = {}
  for k = 1, n do
    local u = k - (n + 1) / 2
    local a = g.tail_ang + u * g.fan
    local len = g.tail * (1 - g.graduated * abs(u) / max(1, (n - 1) / 2))
    list[#list + 1] = { u = u, x2 = ROOT[1] - cos(a) * len, y2 = ROOT[2] + sin(a) * len }
  end
  table.sort(list, function(p, q) return abs(p.u) > abs(q.u) end)
  for i, f in ipairs(list) do
    paint_feather(pt, rng:fork("tf" .. i), map, at, feather(ROOT[1], ROOT[2], f.x2, f.y2, g.tail_w * 1.15, g.tip),
      ROOT, { f.x2, f.y2 }, 16 * sc, 1.05 + 0.04 * i, sc)
    hair(pt, map({ { ROOT[1] + (f.x2 - ROOT[1]) * 0.08, ROOT[2] + (f.y2 - ROOT[2]) * 0.08 },
      { ROOT[1] + (f.x2 - ROOT[1]) * 0.93, ROOT[2] + (f.y2 - ROOT[2]) * 0.93 } }), 0.2 * sc, 0.5)
  end
end

local function wing_field(g)
  local parts = { S.ellipse(-2, 4.6, 7.4 * g.wing, 3.7 * g.wing, 0.2) }
  for k = 1, g.primaries do
    local rb = g.tip == "point" and 0.4 or 1.0
    parts[#parts + 1] = S.capsule(-5, 4.6 - k * 0.3, -11.5 * g.wing - k * 1.0, 3.4 - k * 0.8, 1.6, rb)
  end
  return S.union(parts, 0.9)
end

-- Stroke a closed outline, skipping the points `skip(p)` says to drop, and
-- fading each run's ends so the line dissolves instead of stopping.
local function stroke_except(pt, ring, skip, w, op, rgb, fade)
  local n = #ring
  -- start the walk at a kept point that follows a skipped one
  local start
  for i = 1, n do
    if not skip(ring[i]) and skip(ring[(i - 2) % n + 1]) then start = i break end
  end
  if not start then
    pt:stroke(G.smooth(ring, true), rgb, w, op, MULT)
    return
  end
  local runs, run = {}, {}
  for j = 0, n - 1 do
    local p = ring[(start + j - 1) % n + 1]
    if skip(p) then
      if #run > 1 then runs[#runs + 1] = run end
      run = {}
    else
      run[#run + 1] = p
    end
  end
  if #run > 1 then runs[#runs + 1] = run end
  for _, r in ipairs(runs) do
    local m = #r
    -- The middle is one polyline (no dotted look); only the ends are
    -- stroked piece by piece, fading from nothing to full strength.
    local f = min(fade, math.floor((m - 1) / 2))
    if m - 1 > 2 * f then
      local core = {}
      for i = f + 1, m - f do core[#core + 1] = r[i] end
      pt:stroke(G.smooth(core, false), rgb, w, op, MULT)
    end
    for i = 1, f do
      local a = op * G.smoothstep(0, 1, i / (f + 1))
      pt:stroke(G.polyline({ r[i], r[i + 1] }), rgb, w, a, MULT)
      pt:stroke(G.polyline({ r[m - i + 1], r[m - i] }), rgb, w, a, MULT)
    end
  end
end

local function paint_wing(pt, rng, g, map, at, sc)
  local poly = S.outline(wing_field(g), { -26, -4, 12, 14 }, 0.2, 110)
  -- The wash's own outline is off; its pale end sits at the rounded
  -- front-top, so that is where its edge is most often lost, too.
  W.wash(pt, map(poly), { rng = rng:fork("wing"), size = 14 * sc, ramp = "vivid", part = "blooms",
    axis = { at({ 6, 9 }), at({ -16, 2 }) }, pigment = pal.deep, pool = pal.deep, strength = 1.15,
    simple = true, lost = 0.4, outline = 0, grain = 0.1 })
  -- The outline, by hand: everywhere except the rounded top-front of the coverts.
  local rgb = Color.recolor(pal.ink, Color.part_ink("blooms"))
  stroke_except(pt, map(poly), function(p)
    local lx, ly = (p[1] - at({ 0, 0 })[1]) / sc, (p[2] - at({ 0, 0 })[2]) / sc
    return lx > -4.5 and ly > 5.0
  end, 0.3 * sc, 0.65, rgb, 7)
  for k = 1, g.primaries do
    hair(pt, map({ { -3, 4.6 - k * 0.3 }, { -8, 4.2 - k * 0.55 }, { -11 * g.wing - k * 1.0, 3.4 - k * 0.8 } }), 0.2 * sc, 0.5)
  end
  for row = 0, 2 do
    for c = 0, 3 - row do
      local cx, cy = 3 - row * 0.4 - c * 2.6 - row * 1.2, 5.2 - row * 1.5
      hair(pt, map({ { cx + 1.0, cy + 0.6 }, { cx, cy - 0.3 }, { cx - 1.0, cy + 0.6 } }), 0.16 * sc, 0.45)
    end
  end
end

-- The beak: an upper and a lower mandible from the head's edge, angled down,
-- with a gape line back into the head.
local BEAK = { gold = { 0.86, 0.66, 0.30 }, horn = { 0.30, 0.26, 0.24 }, orange = { 0.93, 0.55, 0.22 } }
local function paint_beak(pt, g, hx, hy, map, at, sc)
  local r = g.head
  local ab = -g.beak_droop                      -- the beak's axis, below horizontal
  local function pol(rad, a) return { hx + rad * cos(a), hy + rad * sin(a) } end
  local P1 = pol(r * 0.93, ab + g.beak_root)     -- forehead end of the root
  local P2 = pol(r * 0.93, ab - g.beak_root * 0.8) -- chin end of the root
  local Qg = pol(r * 0.97, ab - 0.06)            -- the mouth corner on the head's edge
  local T = { hx + (r + g.beak_len) * cos(ab - g.beak_hook * 0.35), hy + (r + g.beak_len) * sin(ab - g.beak_hook * 0.35) }
  local function bow(a, b, k)                     -- a point off the chord, k * its length to the left
    local mx, my = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
    local dx, dy = b[1] - a[1], b[2] - a[2]
    return { mx - dy * k, my + dx * k }
  end
  local culmen = G.spline_points({ P1, bow(P1, T, g.beak_arch), T }, 6)
  local chin = G.spline_points({ P2, bow(P2, T, -g.beak_arch * 0.4), T }, 6)
  local upper, lower = {}, {}
  for _, p in ipairs(culmen) do upper[#upper + 1] = p end
  upper[#upper + 1] = Qg
  lower[#lower + 1] = Qg
  for _, p in ipairs(chin) do lower[#lower + 1] = p end
  local col = BEAK[g.beak_col]
  -- Opaque, so the head's outline does not show through where the beak grows from it.
  pt:fill(G.smooth(map(lower), true), Paint.mix(col, pal.white, 0.3), 1)
  pt:fill(G.smooth(map(upper), true), col, 1)
  pt:fill(G.smooth(map(upper), true), pal.ink, 0.12, MULT)
  pt:stroke(G.smooth(map(culmen), false), pal.ink, 0.26 * sc, 0.7, MULT)
  pt:stroke(G.smooth(map(chin), false), pal.ink, 0.22 * sc, 0.6, MULT)
  -- The gape: from the tip back along the mouth, a little into the head.
  local M = pol(r * 0.78, ab - 0.15)
  pt:stroke(G.smooth(map({ T, Qg, M }), false), pal.ink, 0.22 * sc, 0.65, MULT)
end

local function paint_bird(pt, rng, g, x, y, sc, dir)
  local f, info = body_field(g)
  local function at(p) return { x + dir * p[1] * sc, y + p[2] * sc } end
  local function map(list) local o = {} for i, p in ipairs(list) do o[i] = at(p) end return o end
  local perch = -6.5
  for _, lx in ipairs({ -1.8, 1.4 }) do
    hair(pt, map({ { lx, -3.2 }, { lx + 0.4, -5 }, { lx, perch } }), 0.45 * sc)
    hair(pt, map({ { lx - 1.5, perch + 0.1 }, { lx + 1.9, perch + 0.1 } }), 0.4 * sc)
  end
  paint_tail(pt, rng:fork("tail"), g, map, at, sc)
  local body = map(S.outline(f, { -32, -9, 26, 24 }, 0.25, 110))
  W.wash(pt, body, { rng = rng:fork("body"), size = 22 * sc, ramp = "soft", part = "blooms",
    axis = { at({ 9, 2 }), at({ -11, 5.5 }) }, pigment = pal.blue, pool = pal.deep,
    simple = true, outline = 0.6, outline_w = 0.35 * sc, grain = 0.12 })
  -- The belly: 10 stacked layers of its ink, each a little smaller than the
  -- last at the top edge only, so the colour builds up from nothing.
  local belly_ink = Color.part_ink("leaves")
  local same = belly_ink == Color.part_ink("blooms")   -- one colour: no separate belly
  local belly_rgb = belly_ink and Color.ink_rgb(belly_ink, 0.66) or pal.sky
  local STEPS = 10
  for k = 0, same and -1 or STEPS - 1 do
    local poly = map(S.outline(belly_field(g, f, k * 0.55), { -32, -9, 26, 24 }, 0.3, 80))
    pt:fill(G.smooth(poly, true), belly_rgb, 0.17)
  end
  -- Texture over the layers, as grain only: a full wash here would knock the
  -- layers out with an opaque paper-coloured base and leave pale blobs.
  if not same then
    local core = map(S.outline(belly_field(g, f, 1.2), { -32, -9, 26, 24 }, 0.3, 80))
    W.grain(pt, rng:fork("belly grain"), core, 0.22, { scale = 1, clump = 0.4, mottle = 0.6,
      dark_rgb = belly_ink and Color.ink_rgb(belly_ink, 0.42) or pal.deep, dark_op = 0.3 })
  end
  paint_wing(pt, rng:fork("wing"), g, map, at, sc)
  local hx, hy = info.hx, info.hy
  paint_beak(pt, g, hx, hy, map, at, sc)
  -- A small black bead of an eye with one white highlight, and no ring.
  local e = at({ hx + g.head * 0.28, hy + g.head * 0.2 })
  pt:fill({ { "o", e[1], e[2], g.eye_r * sc } }, { 0.05, 0.05, 0.08 }, 1)
  pt:fill({ { "o", e[1] + dir * g.eye_r * 0.35 * sc, e[2] + g.eye_r * 0.38 * sc, g.eye_r * 0.36 * sc } }, pal.white, 1)
end


-- Entry point with V.bird's signature: (x, y) is the twig tip the feet grip,
-- `dir` is 1 or -1 (which way the bird faces), `L` the old bird's length.
return function(pt, rng, x, y, dir, L)
  local sc = L / 29
  paint_bird(pt, rng:fork("bird"), genes(rng:fork("genes")), x, y + 6.5 * sc, sc, dir)
end
