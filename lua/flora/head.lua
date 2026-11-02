-- The hero as an inflorescence: a raceme, corymb or panicle of watercolour
-- florets crowning the main stem, in place of the single hero bloom.
--
-- Where sprig.lua's inflorescences are pen work for the small holes, this is
-- painted: every floret is a bloom (flower.lua) with the full wash, and the
-- head is built to look dense and a little dimensional.
--
--   * Florets are scattered by phyllotaxis, the golden angle round the axis,
--     so they fill the head evenly with no rows or rings. Each has a depth
--     from that angle: -1 at the back, +1 at the front.
--   * They are painted back to front, each over the last, so the front ones
--     cover what is behind. Back florets are smaller, paler and more tilted;
--     front ones larger, richer and more nearly face-on.
--   * Every floret is tilted in perspective (flower.tilt) about the line
--     from the axis out to it, so those at the sides foreshorten into ovals.
--   * A front floret casts a soft shadow on the ones behind it.
--   * Only the nearest `detail` florets get the full wash; the rest use the
--     wash's simple form, which keeps the page's cost in check.
--   * Pedicels run from the axis to each floret; buds crowd the tip.

local G = require("flora.geom")
local F = require("flora.flower")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Tune = require("flora.tune")
local Brush = require("flora.brush")
local Plant = require("flora.plant")
local Inks = require("flora.inks")
local pal = Paint.palette

local H = {}
local sin, cos, pi = math.sin, math.cos, math.pi
local GOLDEN = 2.39996323

H.kinds = { "bloom", "raceme", "corymb", "panicle" }

-- The head's stem and where it ends. The head's axis is the last stretch of
-- the main stem `st` (already painted by the plant, to its cap) and a
-- continuation that this module paints. Returns the axis points and the
-- continuation's points. `top` is the highest y the head may reach.
local function axis_of(st, hero, top, kind)
  local cfg = Tune.head
  local R = hero[3]
  local pts = st.pts
  local cap = pts[#pts]
  local a = G.angle(pts[#pts - 1], cap)
  local want = cfg.length * R
  -- A corymb opens into a dome wider than the axis is tall: keep it on the page.
  if kind == "corymb" then top = top - R * cfg.width * 1.45 * 0.9 end
  local ext_len = math.max(R * 0.6, math.min(top - cap[2], want * 0.5))
  -- Lean toward the vertical over the continuation, so the head stands up.
  local bend = (pi / 2 - a) * 0.45 + cfg.sway
  local ext = G.curve(cap, a, ext_len, bend, 0, 14)
  -- The stem's own stretch below the cap, up to the rest of the length.
  local base_len, acc, i0 = math.max(0, want - ext_len), 0, #pts
  while i0 > 1 and acc < base_len do
    acc = acc + G.dist(pts[i0 - 1], pts[i0])
    i0 = i0 - 1
  end
  local axis = {}
  for i = i0, #pts do axis[#axis + 1] = pts[i] end
  for i = 2, #ext do axis[#axis + 1] = ext[i] end
  return axis, ext
end

-- Items for one raceme-like run of florets along `axis`: a table of
-- {x, y, r, z, bud, base, deg, phi, u}. `n` florets in all; `scale` shrinks
-- them (for side branches); `t0` is where along the axis they begin.
local function raceme_items(rng, axis, R, n, scale, t0, items)
  local cfg = Tune.head
  local rho = R * cfg.width * scale
  local th0 = rng:range(0, 2 * pi)
  for i = 1, n do
    local u = (i - 0.5) / n
    -- Florets crowd toward the tip: the lowest are the most spread out.
    local t = t0 + (1 - t0) * u ^ 0.75
    local p, a = G.at(axis, t)
    local th = th0 + i * GOLDEN + rng:jit(0.2)
    -- The head is a cone: widest where flowering starts, narrowing to the tip.
    local env = 1 - 0.7 * u ^ 1.3
    local lat = rho * env * cos(th) * rng:range(0.85, 1.1)
    local z = sin(th)
    local na = a + pi / 2
    local rise = R * 0.2 * scale * env * (0.55 + 0.45 * math.abs(cos(th)))
    local c = G.polar(G.polar(p, na, lat), a, rise)
    local bud = u > 1 - cfg.bud_share
    local r = R * cfg.floret * scale * (1 - 0.5 * u) * (0.84 + 0.16 * z) * rng:range(0.9, 1.1)
    items[#items + 1] = {
      x = c[1], y = c[2], r = bud and r * 0.55 or r, z = z + 0.1 * u, bud = bud, base = p, u = u,
      ang = G.angle(p, c), phi = lat >= 0 and na or na + pi,
      side = math.abs(cos(th)),
    }
  end
  -- The tip ends in a tuft of buds not yet opened.
  local tip, ta = G.at(axis, 1)
  for k = 1, 6 do
    local a = ta + (k - 3.5) * 0.28 + rng:jit(0.08)
    local c = G.polar(tip, a, R * 0.05 * scale * rng:range(0.6, 1.3))
    items[#items + 1] = {
      x = c[1], y = c[2], r = R * cfg.floret * scale * 0.2 * rng:range(0.8, 1.2), z = rng:range(-0.2, 0.7),
      bud = true, base = tip, u = 1, ang = a, phi = a, side = 0.5,
    }
  end
end

-- A corymb: florets on a shallow dome over the axis tip (a Vogel spiral
-- seen from above), each on a pedicel from the axis, the outer ones from
-- lower down so they run longer and every floret reaches the dome.
local function corymb_items(rng, axis, R, n, items)
  local cfg = Tune.head
  local tip, ta = G.at(axis, 1)
  local Rd = R * cfg.width * 1.45
  local Hd = Rd * 0.5
  local beta = math.rad(40)
  local th0 = rng:range(0, 2 * pi)
  local cx, cy = tip[1], tip[2] + Rd * 0.15
  for i = 1, n do
    local q = (i - 0.5) / n
    local rho = Rd * math.sqrt(q)
    local th = th0 + i * GOLDEN + rng:jit(0.15)
    local h = Hd * (1 - (rho / Rd) ^ 2)
    local x = cx + rho * cos(th)
    local y = cy + h * cos(beta) - rho * sin(th) * sin(beta)
    local z = G.clamp(sin(th) * (rho / Rd) * 0.85 + (h / Hd) * 0.3 - 0.1, -1, 1)
    local t = 1 - 0.34 * (rho / Rd) ^ 1.1 - rng:range(0, 0.04)
    local base = G.at(axis, t)
    local r = R * cfg.floret * (0.92 + 0.12 * z) * (1 - 0.22 * (rho / Rd)) * rng:range(0.9, 1.1)
    local bud = rho < Rd * 0.3 and rng:chance(cfg.bud_share * 1.4)
    items[#items + 1] = {
      x = x, y = y, r = bud and r * 0.55 or r, z = z, bud = bud, base = base, u = q,
      ang = G.angle(base, { x, y }), phi = math.atan(y - cy, x - cx), side = rho / Rd,
    }
  end
end

-- Push apart florets that sit at nearly the same depth and overlap, so the
-- head stays dense without turning to a clot. Florets at different depths
-- may overlap freely: the front one covers the back.
local function relax(items, passes)
  for _ = 1, passes do
    for i = 1, #items do
      local a = items[i]
      for j = i + 1, #items do
        local b = items[j]
        if math.abs(a.z - b.z) < 0.45 then
          local dx, dy = b.x - a.x, b.y - a.y
          local d = math.sqrt(dx * dx + dy * dy) + 1e-9
          local want = (a.r + b.r) * 0.72
          if d < want then
            local k = (want - d) / d * 0.5
            a.x, a.y, b.x, b.y = a.x - dx * k, a.y - dy * k, b.x + dx * k, b.y + dy * k
          end
        end
      end
    end
  end
end

-- Foreshorten a bloom about (cx, cy): `deg` degrees of tilt about the line
-- along `phi` (the direction the floret leans toward, out from the axis).
local function projector(cx, cy, r, deg, phi)
  local fn = F.tilt(cx, cy, r, deg)
  local c, s = cos(phi - pi / 2), sin(phi - pi / 2)
  return function(x, y)
    local dx, dy = x - cx, y - cy
    local lx, ly = dx * c + dy * s, -dx * s + dy * c
    local ox, oy = fn(cx + lx, cy + ly)
    local ex, ey = ox - cx, oy - cy
    return cx + ex * c - ey * s, cy + ex * s + ey * c
  end
end

-- The bud colour for the hero's ink: a green-yellow for the yellows, a
-- pale wash of the ink otherwise.
local function bud_color(tint)
  if Color.is_yellow(tint) then return Color.oklch(0.80, 0.15, 114) end
  return Paint.mix(Color.recolor(pal.sky, tint), pal.white, 0.25)
end

local function blot(rng, x, y, r)
  local pts = {}
  for k = 0, 15 do
    local a = k * pi / 8
    pts[#pts + 1] = { x + r * cos(a), y + r * sin(a) }
  end
  return G.smooth(G.deform(pts, rng, r * 0.18), true)
end

-- Paint the head at hero = {x, y, R}. `st` is the main stem (plant.lua)
-- whose cap meets the hero; `o.kind` is raceme, corymb or panicle, `o.top`
-- the highest y the head may reach, `o.style` and `o.petals` pick the
-- florets (default: the page's flower style, else cross).
function H.paint(pt, rng, hero, st, o)
  local cfg = Tune.head
  local R = hero[3]
  local kind = o.kind or "raceme"
  local style = o.style or F.flower.style or cfg.style
  local sun = F.styles[style] and F.styles[style].look == "sun"
  local axis, ext = axis_of(st, hero, o.top or hero[2] + R, kind)

  -- Florets, their number picked per head.
  local n = rng:int(cfg.flowers[1], cfg.flowers[2])
  local items, branches = {}, {}
  local ir = rng:fork("items")
  if kind == "corymb" then
    corymb_items(ir, axis, R, n, items)
  elseif kind == "panicle" then
    raceme_items(ir, axis, R, math.floor(n * 0.5), 1, cfg.bare, items)
    for k = 1, 3 do
      local p, a = G.at(axis, 0.48 + 0.15 * k)
      local side = (k % 2 == 0) and 1 or -1
      local len = R * (1.3 - 0.2 * k)
      local br = G.curve(p, a + side * ir:range(0.6, 0.85), len, -side * 0.35 + ir:jit(0.15), 0, 12)
      branches[#branches + 1] = br
      raceme_items(ir, br, R, math.max(5, math.floor(n * 0.16)), 0.62, 0.15, items)
    end
  else
    raceme_items(ir, axis, R, n, 1, cfg.bare, items)
  end
  relax(items, cfg.relax)

  -- The continuation of the stem, tapering to a fine tip.
  local w0 = Plant.width_at(st, st.len)
  local cont = Plant.stem(ext, w0, math.max(1.2, w0 * 0.45))
  Brush.stem(pt, rng:fork("stem"), ext, Plant.width_fn(cont), Tune.plant)
  for k, br in ipairs(branches) do
    local bs = Plant.stem(br, 2.2, 0.9)
    Brush.stem(pt, rng:fork("branch" .. k), br, Plant.width_fn(bs), Tune.plant)
  end

  -- Pods, hanging below the lowest florets of a raceme.
  local tone = Paint.mix(Brush.stem_tone(Tune.plant), pal.white, 0.3)
  if kind ~= "corymb" and cfg.pods > 0 then
    local pr, pods = rng:fork("pods"), {}
    for k = 1, cfg.pods do
      local p, a = G.at(axis, pr:range(0.06, cfg.bare + 0.04))
      local side = (k % 2 == 0) and 1 or -1
      local len = R * pr:range(0.45, 0.65)
      local pod = G.curve(p, a + side * pr:range(0.5, 0.8), len, -side * 0.3, 0, 8)
      pods[#pods + 1] = G.smooth(G.ribbon(pod, function(t) return (R * 0.012 + 0.4) * (1 - t ^ 3) end), true)
    end
    pt:fill(pods, tone, 0.8, { many = true, blend = "multiply" })
  end

  -- Back to front. The nearest `detail` open florets get the full wash.
  table.sort(items, function(a, b) return a.z < b.z end)
  local order = {}
  for i, it in ipairs(items) do if not it.bud then order[#order + 1] = i end end
  local full = {}
  for k = #order, math.max(1, #order - cfg.detail + 1), -1 do full[order[k]] = true end

  -- The hero's ink, or its style's when the palette leaves it on look.
  local tint = Color.part_ink("hero") or (F.styles[style] and F.styles[style].ink)
  local shadow = Color.recolor(pal.deep, tint)
  local bud_rgb = bud_color(tint)
  local groups = 4
  local per = math.ceil(#items / groups)
  local fr = rng:fork("florets")
  for gi = 1, groups do
    local lo, hi = (gi - 1) * per + 1, math.min(#items, gi * per)
    -- Pedicels of this depth band, under its florets.
    local peds = {}
    for i = lo, hi do
      local it = items[i]
      local from, to = it.base, { it.x, it.y }
      local mid = G.mix(from, to, 0.5)
      local len = G.dist(from, to)
      local bow = G.polar(mid, G.angle(from, to) + pi / 2, len * 0.12 * ((i % 2 == 0) and 1 or -1))
      local line = G.spline_points({ from, bow, to }, 4)
      peds[#peds + 1] = G.smooth(G.ribbon(line, function(t) return (R * 0.004 + 0.25) * (1 - 0.4 * t) end), true)
    end
    if #peds > 0 then pt:fill(peds, tone, 0.9, { many = true, blend = "multiply" }) end
    for i = lo, hi do
      local it = items[i]
      local zn = (it.z + 1) / 2
      if it.bud then
        F.bud(pt, it.x, it.y, it.ang, it.r * 1.3, bud_rgb)
        pt:fill({ { "o", it.x + it.r * 0.1, it.y + it.r * 0.3, it.r * 0.3 } }, pal.white, 0.3)
      else
        -- A soft shadow on whatever is behind, down and to the right.
        local behind = false
        for j = math.max(1, i - 24), i - 1 do
          local o2 = items[j]
          if G.dist({ it.x, it.y }, { o2.x, o2.y }) < (it.r + o2.r) * 0.95 then behind = true break end
        end
        local deg = G.clamp(cfg.tilt[1] + (cfg.tilt[2] - cfg.tilt[1]) * it.side ^ 1.2 + (it.z < 0 and -it.z * 10 or 0), 0, 75)
        pt:project(projector(it.x, it.y, it.r, deg, it.phi))
        -- A concave (cupped) floret: the petal that points out, away from the axis,
        -- is brought back toward the viewer (less tilted, so rounder and
        -- larger); the others keep the full tilt. cup is how far.
        local cup = cfg.cup
        local function petal_project(a)
          local w = math.max(0, cos(a - it.phi)) ^ cfg.cup_focus
          if w <= 0 or cup <= 0 then return nil end
          return projector(it.x, it.y, it.r, deg * (1 - cup * w), it.phi)
        end
        -- Foreshortened with its floret, so it never shows past the petals.
        if behind then
          local sr = fr:fork("shadow" .. i)
          pt:fill(blot(sr, it.x + it.r * 0.08, it.y - it.r * 0.12, it.r * 0.8), shadow, cfg.shade * (0.5 + 0.5 * zn), { blend = "multiply" })
        end
        F.bloom(pt, fr:fork("f" .. i), it.x, it.y, it.r, {
          style = style, petals = o.petals, part = "hero", look = sun and "sun" or "hero",
          simple = not full[i], strength = 1 - cfg.fade * (1 - zn),
          petal_project = petal_project,
        })
        pt:project(nil)
      end
    end
  end
end

-- Discs {x, y, r} covering the head's footprint for a hero at (hx, hy) of
-- radius R, for the clearance field, before the stem is grown: a column
-- straight below the hero's centre, as wide as the cluster.
function H.footprint(hero, kind)
  local cfg = Tune.head
  local R = hero[3]
  local out = {}
  local rho = R * cfg.width * (kind == "corymb" and 1.6 or 1.15) + R * cfg.floret
  local len = (kind == "corymb" and 1.0 or cfg.length * 0.8) * R
  for k = 0, 8 do
    local t = k / 8
    local env = kind == "corymb" and 1 or (1 - 0.6 * t)
    out[#out + 1] = { hero[1], hero[2] - len * (1 - t) + R * 0.3 * t, rho * env }
  end
  return out
end

return H
