-- The painted bee (animals=painted): a stout, nearly round abdomen crossed
-- by dark bands, overlapped by a dark thorax and a small head, in profile.
-- It has four wings, as a real bee does: a larger forewing and a smaller
-- hindwing on each side, rooted at the top of the thorax and swept back and
-- up. The near pair is painted over the body, glassy enough to show the
-- stripes through it, with a faint tint of the abdomen's ink; the far pair
-- is only a ghost behind. The forewing has a leading-edge vein and a dark
-- pterostigma, the rest is left plain so the bee stays clear at 15 to 25
-- pt. Antennae are elbowed; the eye is a single white glint.
--
-- Colour: the abdomen is the `blooms` ink, the dark parts (bands, thorax,
-- head, legs, wing lines) a deep tone of the `leaves` ink. Bright inks are
-- read a little deeper for the bee, so a pale abdomen keeps its bands.
-- Genes (build, bands, wing size and lift) come from the random stream.

local G = require("flora.geom")
local W = require("flora.wash")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Tune = require("flora.tune")
local pal = Paint.palette
local MULT = { blend = "multiply" }
local cos, sin, pi = math.cos, math.sin, math.pi

-- Pen widths for the wings, in points (they stay fine as the bee scales).
local WING_EDGE, WING_VEIN = 0.65, 0.54

local function genes(rng)
  return {
    abd_rx = rng:range(3.9, 4.6), abd_ry = rng:range(3.3, 3.9),
    thorax = rng:range(2.2, 2.7), thorax_flat = rng:range(0.88, 1.0),
    head = rng:range(1.6, 2.0),
    stinger = rng:range(1.0, 1.8),
    stripes = rng:int(2, 3), stripe_w = rng:range(1.0, 1.5),
    fuzz = rng:int(6, 12), squash = rng:range(0.0, 0.12),
    -- wings: size, and how far up (a larger number is more upright)
    wing = rng:range(0.9, 1.15), lift = rng:range(-0.12, 0.18),
  }
end

-- Where a wing is: its half-width at fraction t of its length.
local function half_width(wmax, t) return wmax * sin(pi * t ^ 0.7) ^ 0.8 end

-- A wing's outline in its own frame: root at the origin, extending along +x,
-- leading edge toward -y (straighter), trailing edge toward +y (fuller).
local function wing_outline(len, wmax)
  local up, lo, n = {}, {}, 14
  for i = 0, n do
    local t = i / n
    local w = half_width(wmax, t)
    up[#up + 1] = { t * len, -w * 0.78 }
    lo[#lo + 1] = { t * len, w * 1.12 }
  end
  local out = {}
  for i = 1, #up do out[#out + 1] = up[i] end
  for i = #lo - 1, 2, -1 do out[#out + 1] = lo[i] end
  return out
end

-- One wing at `root` pointing along `dir` (in the bee's frame), `len` long.
-- `veins` adds the leading-edge vein (and, for a forewing, the pterostigma).
local function paint_wing(pt, tone, root, dir, len, wmax, fore, alpha, veins, tint, map)
  local c, s = cos(dir), sin(dir)
  local function L(list)
    local o = {}
    for i, p in ipairs(list) do
      o[i] = { root[1] + p[1] * c - p[2] * s, root[2] + p[1] * s + p[2] * c }
    end
    return map(o)
  end
  local shape = G.smooth(L(wing_outline(len, wmax)), true)
  pt:fill(shape, pal.white, 0.42 * alpha)
  pt:fill(shape, tint, 0.12 * alpha, MULT)
  pt:stroke(shape, tone, WING_EDGE, 0.35 * alpha, MULT)
  if not veins then return end
  local costal = {}
  for i = 0, 7 do
    local t = 0.05 + 0.8 * i / 7
    costal[#costal + 1] = { t * len, -half_width(wmax, t) * 0.72 }
  end
  pt:stroke(G.polyline(L(costal)), tone, WING_VEIN, 0.32 * alpha, MULT)
  if fore then
    -- The pterostigma: a small dark cell on the leading edge, near the tip.
    local cell = {}
    for i = 0, 8 do
      local t = 0.6 + 0.12 * i / 8
      cell[#cell + 1] = { t * len, -half_width(wmax, t) * 0.76 }
    end
    for i = 8, 0, -1 do
      local t = 0.6 + 0.12 * i / 8
      cell[#cell + 1] = { t * len, -half_width(wmax, t) * 0.5 }
    end
    pt:fill(G.smooth(L(cell), true), tone, 0.5 * alpha, MULT)
  end
end

local function ellipse(cx, cy, rx, ry, n)
  local o = {}
  for i = 0, n - 1 do
    local a = 2 * pi * i / n
    o[#o + 1] = { cx + rx * cos(a), cy + ry * sin(a) }
  end
  return o
end

local function paint_bee(pt, rng, g, x, y, ang, sc)
  local abd_ink = Color.part_ink("blooms")
  local dark_ink = Color.part_ink("leaves")
  local dark = dark_ink and Color.ink_rgb(dark_ink, 0.22) or pal.ink
  -- With no ink for the part (the "look" palette) the abdomen is honey gold.
  local function abd_rgb(l, fallback) return abd_ink and Color.ink_rgb(abd_ink, l) or fallback end
  local tint = abd_rgb(0.9, pal.gold)
  local ca, sa = cos(ang), sin(ang)
  local function at(p) return { x + (p[1] * ca - p[2] * sa) * sc, y + (p[1] * sa + p[2] * ca) * sc } end
  local function map(list)
    local o = {}
    for i, p in ipairs(list) do o[i] = at(p) end
    return o
  end
  local function hair(pts, w, op)
    pt:stroke(G.polyline(map(pts)), dark, w, op or 0.85, MULT)
  end
  local AX = -2.1                -- abdomen centre: close to the thorax, so they overlap
  local TX, HX = 1.9, 4.1        -- thorax and head centres
  local top = g.thorax * g.thorax_flat
  -- A forewing over a hindwing each side, swept well back and a little up.
  local fdir, hdir = 2.46 - g.lift, 2.74 - g.lift
  local flen, hlen = 7.6 * g.wing, 5.4 * g.wing
  local function pair(dx, dy, da, alpha, veins)
    local root = { TX - 0.3 + dx, top - 0.35 + dy }
    paint_wing(pt, dark, root, hdir + da, hlen, 2.0 * g.wing, false, alpha, veins, tint, map)
    paint_wing(pt, dark, { root[1] + 0.25, root[2] + 0.1 }, fdir + da, flen, 2.5 * g.wing, true, alpha, veins, tint, map)
  end
  pair(-0.4, 0.3, 0.12, 0.3, false)       -- the far pair, a ghost behind the body
  for k = -1, 1 do                         -- short legs
    hair({ { TX - 0.6 + k * 1.2, -2.4 }, { TX - 1.0 + k * 1.6, -3.6 }, { TX - 1.4 + k * 1.8, -4.3 } }, 0.3 * sc)
  end
  hair({ { AX - g.abd_rx + 0.5, 0 }, { AX - g.abd_rx - g.stinger, 0 } }, 0.5 * sc, 0.9)   -- a plain stinger
  local abd = map(ellipse(AX, 0, g.abd_rx, g.abd_ry * (1 + g.squash), 36))
  W.wash(pt, abd, { rng = rng:fork("abd"), size = 6 * sc,
    pigment = abd_rgb(0.55, pal.gold), pool = abd_rgb(0.25, pal.copper),
    simple = true, rings = 5, lift = 0.12, grain = 0.4, outline = 0.6, outline_w = 0.3 * sc })
  -- Bands across the abdomen; one more than shows, under the thorax, so the
  -- body reads as one piece.
  pt:clip_begin(G.smooth(abd, true))
  local step = (g.abd_rx * 1.25) / g.stripes
  for k = 0, g.stripes do
    local bx = AX - g.abd_rx * 0.62 + k * step
    pt:stroke(G.polyline(map({ { bx + 0.4, -5 }, { bx - 0.4, 5 } })), dark, g.stripe_w * sc, 0.82, MULT)
  end
  pt:clip_end()
  pt:fill(G.smooth(map(ellipse(TX, 0, g.thorax, top, 28)), true), dark, 0.88, MULT)
  pt:fill(G.smooth(map(ellipse(HX, 0.2, g.head, g.head * 0.95, 24)), true), dark, 0.92, MULT)
  for k = 1, g.fuzz do                     -- a little fuzz on the thorax
    local a = pi * (0.1 + 0.8 * rng:next()) * (k % 2 == 0 and 1 or -1)
    local p0 = { TX + g.thorax * cos(a), top * sin(a) }
    hair({ p0, { p0[1] + 0.9 * cos(a + 0.2), p0[2] + 0.9 * sin(a + 0.2) } }, 0.16 * sc, 0.55)
  end
  pair(0, 0, 0, 0.85, true)                -- the near pair, over the body
  local e = at({ HX + 0.55, 0.6 })
  pt:fill({ { "o", e[1], e[2], 0.3 * sc } }, pal.white, 0.9)
  -- Elbowed antennae: a short scape up and forward, a bend, then the
  -- flagellum ending in a small club. The far one is fainter.
  for i, d in ipairs({ 1, 0.7 }) do
    local P = { { HX + 0.9, 1.3 }, { HX + 1.7, 2.7 * d + 0.2 }, { HX + 3.4, 2.4 * d + 0.4 }, { HX + 4.7, 1.4 * d + 0.5 } }
    local op = i == 1 and 0.9 or 0.6
    pt:stroke(G.smooth(map(P), false), dark, 0.25 * sc, op, MULT)
    local q = at(P[4])
    pt:fill({ { "o", q[1], q[2], 0.4 * sc } }, dark, op, MULT)
  end
end

-- Same arguments as V.bee: the bee at (x, y) heading `ang`, about L long.
return function(pt, rng, x, y, ang, L)
  local saved = Tune.color.bright
  Tune.color.bright = { depth = 0.5 }
  local ok, err = pcall(paint_bee, pt, rng:fork("bee"), genes(rng:fork("genes")), x, y, ang, L / 13)
  Tune.color.bright = saved
  if not ok then error(err, 0) end
end
