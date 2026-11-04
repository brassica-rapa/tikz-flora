-- The looks of raster gilt (gilt_look.lua, tune.lua's gilt_looks): the
-- tuned studio look paints what it always has, every key of every look
-- reaches the image, and per-document keys are checked by name.
local H = dofile("tests/helper.lua")
local G = require("flora.geom")
local Paint = require("flora.paint")
local Tune = require("flora.tune")
local Look = require("flora.gilt_look")
local Raster = require("flora.orn_raster")
local Settings = require("flora.settings")

-- A specimen with every kind of surface: a rounded bar under a crossing
-- copper bar, a four-pointed star of two-faced rays, a wire stroke and a
-- row of beads, all casting shadows.
local function specimen()
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  local function rect(x0, y0, x1, y1) return G.polyline({ { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }, true) end
  Raster.add(pt, "fill", { rect(4, 20, 36, 28) }, { bevel = 0.7, shadow = 0.5 })
  Raster.add(pt, "fill", { rect(16, 6, 24, 42) }, { bevel = 0.7, shadow = 0.5, tone = "shade" })
  local lit, shade = {}, {}
  for k = 0, 3 do
    local a = math.pi / 2 + k * math.pi / 2
    local tip = G.polar({ 62, 24 }, a, 18)
    lit[k + 1] = G.polyline({ { 62, 24 }, tip, G.polar({ 62, 24 }, a + math.pi / 2, 4) }, true)
    shade[k + 1] = G.polyline({ { 62, 24 }, tip, G.polar({ 62, 24 }, a - math.pi / 2, 4) }, true)
  end
  Raster.add(pt, "fill", shade, { bevel = 0.5, shadow = 0.4, tone = "shade" })
  Raster.add(pt, "fill", lit, { bevel = 0.5, shadow = 0.4 })
  Raster.add(pt, "stroke", { G.polyline({ { 84, 6 }, { 96, 24 }, { 84, 42 } }) }, { width = 1.2, shadow = 0.36 })
  local beads = {}
  for i = 0, 3 do
    local ring = {}
    for j = 0, 23 do ring[#ring + 1] = G.polar({ 104, 8 + i * 11 }, j * math.pi / 12, 3) end
    beads[#beads + 1] = G.polyline(ring, true)
  end
  Raster.add(pt, "fill", beads, { bevel = 0.6, shadow = 0.3, whole = true })
  return pt.gilt_pending
end

local function digest(im)
  local h = 7
  for _, s in ipairs({ im.rgb, im.alpha }) do
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967291 end
  end
  return h
end

local function render(look, over)
  return Raster.render(specimen(), 150, nil, look, over)
end

-- The tuned studio look is the default and paints exactly what it did
-- before its numbers became parameters (this digest was taken from the
-- code with its numbers written in).
H.check(Tune.gilt_env == "studio", "the default look is " .. tostring(Tune.gilt_env))
local base = render()
H.check(digest(base) == digest(render("studio")), "the default look is not the studio look")
H.check(digest(base) == 632863055, "the studio look's image changed: digest " .. digest(base))

-- Each look has exactly the keys its environment reads, every one within
-- its range, and the ramps and shadow colour.
for name, L in pairs(Tune.gilt_looks) do
  for k, r in pairs(Look.keys) do
    local wanted = r[4] == nil or r[4] == name
    H.check((L[k] ~= nil) == wanted, string.format("the %s look %s key %s", name, wanted and "lacks" or "has the foreign", k))
    if L[k] ~= nil then H.check(Look.check(k, L[k]) == L[k], string.format("the %s look's %s (%s) is out of range", name, k, L[k])) end
  end
  H.check(#L.gold >= 2 and #L.copper >= 2 and #L.umber == 3, "the " .. name .. " look lacks a ramp or its shadow colour")
end

-- Every key of every look changes the image: none is left unread.
for name, L in pairs(Tune.gilt_looks) do
  local ref = digest(render(name))
  for k, r in pairs(Look.keys) do
    if L[k] ~= nil then
      -- The end of the range furthest from the tuned value, except where
      -- the window's foot must stay below its top.
      local v = (L[k] - r[1] > r[2] - L[k]) and r[1] or r[2]
      if k == "window_foot" then v = 0 elseif k == "window_top" then v = 0.3 end
      if k == "sparkle_glint" then
        H.check(digest(render(name, { sparkle = 40, sparkle_glint = v })) ~= digest(render(name, { sparkle = 40 })),
          string.format("sparkle_glint does not change the %s look", name))
      else
        H.check(digest(render(name, { [k] = v })) ~= ref, string.format("%s=%s does not change the %s look", k, v, name))
      end
    end
  end
end

-- Knobs move the gold the way their names say. With no shadow, alpha is
-- coverage alone; a lower ground darkens the image; light from the lower
-- right lights the star's lower right face rather than its upper left.
do
  local function alpha_sum(im)
    local s = 0
    for i = 1, #im.alpha do s = s + im.alpha:byte(i) end
    return s
  end
  local function lum(im)
    local s = 0
    for i = 1, #im.rgb do s = s + im.rgb:byte(i) end
    return s
  end
  local flat = render("studio", { shadow = 0 })
  local cov = 0
  for i = 1, #flat.coverage do cov = cov + math.floor(math.min(1, flat.coverage[i]) * 255 + 0.5) end
  H.check(alpha_sum(flat) == cov, "with shadow=0 the image's alpha is not its coverage")
  H.check(alpha_sum(base) > cov, "the studio look casts no shadow")
  H.check(lum(render("studio", { ground = 0 })) < lum(base), "ground=0 does not darken the gold")
  H.check(lum(render("studio", { sky = 0.9 })) > lum(base), "sky=0.9 does not brighten the gold")
end

-- Per-document keys: parsed with ranges, errors naming the key; keys of
-- another look, and a window whose foot is above its top, are refused
-- when the look is resolved.
do
  local set = Settings.parse("giltlook={horizon=0.1, grain=0}")
  H.check(set.giltlook.horizon == 0.1 and set.giltlook.grain == 0, "giltlook lost its keys")
  local merged = Settings.merge(set, Settings.parse("giltlook={sky=0.6}"))
  H.check(merged.giltlook.horizon == 0.1 and merged.giltlook.sky == 0.6, "a second giltlook drops the first's keys")
  for bad, says in pairs({ ["giltlook={horizon=2}"] = "horizon must be a number from %-0.5 to 0.5",
    ["giltlook={glow=1}"] = "no gilt look key \"glow\"", ["giltlook={sky=x}"] = "sky must be a number" }) do
    local ok, err = pcall(Settings.parse, bad)
    H.check(not ok and tostring(err):find(says), bad .. " is not refused by name: " .. tostring(err))
  end
  local ok, err = pcall(Look.resolve, "studio", { band = 0.3 })
  H.check(not ok and tostring(err):find("band belongs to the mirror look"), "a mirror key passes on studio: " .. tostring(err))
  ok, err = pcall(Look.resolve, "studio", { window_foot = 0.5, window_top = 0.4 })
  H.check(not ok and tostring(err):find("window_foot"), "a window foot above its top passes: " .. tostring(err))
  H.check(Look.resolve("studio") == Tune.gilt_looks.studio, "resolving with no keys copies the look")
  -- A document's keys reach its gilt: the painter carries them to the image.
  Paint.reset_resources()
  local pt = Paint.new({ backend = "pdf", gilt = "raster" })
  pt.gilt_look = { ground = 0 }
  local seen
  local place = Raster.place
  Raster.place = function(_, im) seen = im end
  Raster.add(pt, "fill", { G.polyline({ { 0, 0 }, { 20, 0 }, { 20, 8 }, { 0, 8 } }, true) }, { bevel = 0.7 })
  Raster.flush(pt)
  Raster.place = place
  local p2 = Paint.new({ backend = "pdf", gilt = "raster" })
  local plain
  Raster.place = function(_, im) plain = im end
  Raster.add(p2, "fill", { G.polyline({ { 0, 0 }, { 20, 0 }, { 20, 8 }, { 0, 8 } }, true) }, { bevel = 0.7 })
  Raster.flush(p2)
  Raster.place = place
  H.check(seen and plain and seen.rgb ~= plain.rgb, "the painter's giltlook keys do not reach its gilt")
end

H.done("gilt look")
