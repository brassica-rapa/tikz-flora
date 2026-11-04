local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Settings = require("flora.settings")
local Tune = require("flora.tune")
local Mix = require("flora.mix")

local function page(seed, mix, palette)
  local s = H.page(seed)
  s.mix, s.palette = mix, palette
  Paint.reset_resources()
  return Compose.page(s)
end

-- Neutral weights are the unmixed page exactly.
do
  local neutral = {}
  for k, v in pairs(Tune.mix) do neutral[k] = v end
  H.check(page(3):code() == page(3, neutral):code(), "a neutral mix changed the page")
end

-- Weight 0 removes a kind; a large weight brings more of it.
do
  local base, none, many = { umbel = 0, lily = 0, leaves = 0 }, { umbel = 0, lily = 0, leaves = 0 }, { umbel = 0 }
  for seed = 1, 4 do
    local d = page(seed).counts
    local z = page(seed, { umbel = 0, lily = 0, leaves = 0 }).counts
    local m = page(seed, { umbel = 4 }).counts
    base.umbel, base.lily, base.leaves = base.umbel + (d.umbel or 0), base.lily + (d.lily or 0), base.leaves + d.leaves
    none.umbel, none.lily, none.leaves = none.umbel + (z.umbel or 0), none.lily + (z.lily or 0), none.leaves + z.leaves
    many.umbel = many.umbel + (m.umbel or 0)
  end
  H.check(base.umbel > 0 and base.lily > 0 and base.leaves > 0,
    string.format("default pages lack umbels, lilies or leaves (%d, %d, %d)", base.umbel, base.lily, base.leaves))
  H.check(none.umbel == 0 and none.lily == 0 and none.leaves == 0,
    string.format("weight 0 still grew %d umbels, %d lilies, %d leaves", none.umbel, none.lily, none.leaves))
  H.check(many.umbel > base.umbel * 1.5,
    string.format("umbel=4 grew %d umbels against %d by default", many.umbel, base.umbel))
end

-- Density thins the whole border.
do
  local full, airy = 0, 0
  for seed = 1, 3 do
    full = full + #page(seed):body()
    airy = airy + #page(seed, { density = 0.4 }):body()
  end
  H.check(airy < full * 0.85, string.format("density=0.4 painted %.0f%% of the default", 100 * airy / full))
end

-- A palette changes the page and is undone afterwards, even on error.
do
  local before = Tune.color.palette.leaves
  H.check(page(2, nil, { leaves = "warm" }):code() ~= page(2):code(), "palette leaves=warm changed nothing")
  H.check(Tune.color.palette.leaves == before, "palette override leaked into tune")
  local Mix = require("flora.mix")
  pcall(Mix.with_palette, { leaves = "warm" }, function() error("boom") end)
  H.check(Tune.color.palette.leaves == before, "palette override leaked after an error")
end

-- A random palette spins colours only: every painted point stays where it
-- was, and different spins give different colours.
do
  local function run(palette, spin)
    local s = H.page(4)
    s.palette, s.spin = palette, spin
    local pts = {}
    s.probe = function(x, y) pts[#pts + 1] = x * 1000 + y end
    Paint.reset_resources()
    return Compose.page(s):code(), pts
  end
  local look, p0 = run(nil)
  local a, p1 = run({ leaves = "random", blooms = "random", hero = "random" }, 1)
  local b, p2 = run({ leaves = "random", blooms = "random", hero = "random" }, 2)
  local a2 = run({ leaves = "random", blooms = "random", hero = "random" }, 1)
  local same = #p0 == #p1 and #p1 == #p2
  for i = 1, #p0 do if p0[i] ~= p1[i] or p1[i] ~= p2[i] then same = false break end end
  H.check(same, "a random palette moved the shapes")
  H.check(a ~= look and a ~= b, "spinning the random palette did not change the colours")
  H.check(a == a2, "the same spin gave different colours")
end

-- Settings fold density and visitors into the mix and reject bad values.
do
  local t = Settings.parse("mix={lily=2, umbel=0}, density=0.7, visitors=1, mix={bee=0}")
  H.check(t.mix.lily == 2 and t.mix.umbel == 0 and t.mix.density == 0.7, "mix settings lost")
  H.check(t.mix.butterfly == 1 and t.mix.bee == 0, "visitors shorthand or a later override lost")
  local p = Settings.parse("palette={leaves=green, hero=kon-peki, stems=look}")
  H.check(p.palette.leaves == "green" and p.palette.hero == "kon-peki", "palette settings lost")
  H.check(Settings.parse("palette={leaves=random}, spin=3").spin == 3, "spin lost")
  for _, bad in ipairs({ "spin=1.5", "mix={rose=1}", "mix={lily=-1}", "mix={lily=many}", "density=11",
      "palette={leaves=plaid}", "palette={petals=green}", "visitors=lots", "colourway=plaid" }) do
    H.check(not pcall(Settings.parse, bad), "accepted bad settings \"" .. bad .. "\"")
  end
end

-- A colourway sets every part at once, in order with palette={...}: a
-- palette after it changes one part, a colourway after a palette replaces
-- it. Every colourway names a real ink or group for every part, and no two
-- are the same.
do
  local Inks = require("flora.inks")
  local w = Settings.parse("colourway=winter, palette={hero=momiji}").palette
  H.check(w.hero == "momiji" and w.blooms == "fuyu-gaki" and w.cartouche == "shin-kai", "palette after a colourway lost a part")
  local o = Settings.parse("palette={hero=momiji}, colourway=winter").palette
  H.check(o.hero == "tsuki-yo", "a colourway after a palette left its hero")
  local fall, autumn = Settings.parse("colourway=fall").palette, Settings.parse("colourway=autumn").palette
  local orig = Settings.parse("palette={leaves=teal}, colourway=original").palette
  local seen = {}
  for _, name in ipairs(Inks.colourway_order) do
    local pal = Settings.parse("colourway=" .. name).palette
    local parts = {}
    for part, def in pairs(Tune.color.palette) do
      local ink = pal[part]
      if name == "original" then H.check(ink == def and orig[part] == def, "original is not tune.lua's palette at " .. part) end
      H.check(ink == "look" or Inks.groups[ink] or Inks.ramps[ink], name .. " paints " .. part .. " with unknown ink " .. tostring(ink))
      if name == "autumn" then H.check(fall[part] == ink, "fall is not autumn at " .. part) end
      parts[#parts + 1] = part .. "=" .. tostring(ink)
    end
    table.sort(parts)
    local key = table.concat(parts, ",")
    H.check(not seen[key], name .. " repeats " .. tostring(seen[key]))
    seen[key] = name
  end
  for name in pairs(Inks.colourways) do
    local listed = false
    for _, n in ipairs(Inks.colourway_order) do listed = listed or n == name end
    H.check(listed, "colourway " .. name .. " is missing from colourway_order")
  end
end

-- The fixed blues follow the palette: with every part in a red ink, almost
-- no painted colour is still blue (the default page is over a third blue).
-- Pen line work in stamens and stem brushwork stays navy by design.
do
  local function oklab(r, g, b)
    local function dec(c) if c <= 0.04045 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
    r, g, b = dec(r), dec(g), dec(b)
    local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
    local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
    local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
    return 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  end
  local function blue_share(palette)
    local n, blue = 0, 0
    for r, g, b in page(1, nil, palette):code():gmatch("([%d.]+) ([%d.]+) ([%d.]+) [rR][gG]") do
      local A, B = oklab(tonumber(r), tonumber(g), tonumber(b))
      local h = math.deg(math.atan(B, A)) % 360
      n = n + 1
      if math.sqrt(A * A + B * B) > 0.06 and h > 215 and h < 300 then blue = blue + 1 end
    end
    return blue / n
  end
  local red = {}
  for part in pairs(Tune.color.palette) do red[part] = "momiji" end
  local base, all = blue_share(nil), blue_share(red)
  H.check(base > 0.25, string.format("the default page is only %.2f blue; the measure is broken", base))
  H.check(all < 0.012, string.format("%.3f of the colours stay blue with every part in momiji", all))
  -- Batched shapes share one colour operator, so check the florets and the
  -- cartouche directly: in a red ink none of their colours is blue.
  local Flower = require("flora.flower")
  local Ornament = require("flora.ornament")
  local Rng = require("flora.rng")
  local function blues(palette, draw)
    local pt = Paint.new({ backend = "pdf" })
    Mix.with_palette(palette, function() draw(pt) end)
    local k = 0
    for r, g, b in pt:code():gmatch("([%d.]+) ([%d.]+) ([%d.]+) [rR][gG]") do
      local A, B = oklab(tonumber(r), tonumber(g), tonumber(b))
      local h = math.deg(math.atan(B, A)) % 360
      if math.sqrt(A * A + B * B) > 0.06 and h > 215 and h < 300 then k = k + 1 end
    end
    return k
  end
  local florets = function(pt)
    Flower.florets(pt, { { 10, 10, 2, 0, 1 }, { 20, 10, 2, 0, 2 }, { 30, 10, 2, 0, 3 }, { 40, 10, 2, 0, 2, true } })
  end
  local panel = function(pt) Ornament.panel(pt, Rng.new(5), 0, 0, 40, 60) end
  H.check(blues(nil, florets) > 0 and blues(nil, panel) > 0, "the default florets or cartouche are not blue")
  H.check(blues({ sprays = "momiji" }, florets) == 0, "florets stay blue with sprays=momiji")
  H.check(blues({ cartouche = "momiji" }, panel) == 0, "the cartouche stays blue with cartouche=momiji")
  -- Each of the parts that recolour fixed blues changes the page on its own.
  for _, part in ipairs({ "sprays", "ghost", "cartouche" }) do
    local changed = false
    for seed = 1, 4 do
      if page(seed, nil, { [part] = "momiji" }):code() ~= page(seed):code() then changed = true break end
    end
    H.check(changed, "palette " .. part .. "=momiji changed nothing")
  end
  local p = Settings.parse("palette={sprays=warm, ghost=random, cartouche=yu-yake}")
  H.check(p.palette.sprays == "warm" and p.palette.ghost == "random" and p.palette.cartouche == "yu-yake",
    "new palette parts lost")
end

-- Leaf shapes and bloom styles: the mix weighs them on a page. Drawn under
-- a mix that zeroes the others, every large leaf takes the one shape left
-- and every small bloom the one style left; small leaves stay lance.
do
  local L = require("flora.leaf")
  local F = require("flora.flower")
  local Rng = require("flora.rng")
  local margins = { feather = "feather", acanthus = "acanthus", lance = "entire" }
  for shape, margin in pairs(margins) do
    local only = { feather = 0, acanthus = 0, lance = 0 }
    only[shape] = 1
    Mix.with_mix(only, function()
      local r = Rng.new(11)
      for _ = 1, 60 do
        local o = L.options(r, 100, 0.4)
        H.check(o.margin == margin, string.format("mix leaving only %s drew a %s leaf", shape, o.margin))
      end
      H.check(L.options(r, 30, 0.4).margin == "entire", "a small leaf was not a lance leaf")
    end)
  end
  local seen = {}
  Mix.with_mix({ fan = 0 }, function()
    local r = Rng.new(5)
    for _ = 1, 40 do seen[F.pick_style(r, { "fan", "round" })] = true end
  end)
  H.check(seen.round and not seen.fan, "fan=0 still picked fan blooms")
  H.check(Mix.active == nil, "with_mix left its mix active")
  -- Outside a page the defaults hold: both shapes turn up.
  local any = {}
  local r = Rng.new(2)
  for _ = 1, 80 do any[L.options(r, 100, 0.4).margin] = true end
  H.check(any.feather and any.acanthus and any.entire, "default odds never drew some leaf shape")
  -- A real page grows its leaves under the page's mix.
  local drawn = {}
  local options = L.options
  L.options = function(rr, len, ang)
    local o = options(rr, len, ang)
    drawn[o.margin] = (drawn[o.margin] or 0) + 1
    return o
  end
  page(3, { feather = 0, acanthus = 0 })
  L.options = options
  H.check((drawn.entire or 0) > 0 and not drawn.feather and not drawn.acanthus,
    "a page with feather=0, acanthus=0 still grew lobed leaves")
  local p = Settings.parse("mix={feather=2, acanthus=0, lance=1, fan=0.5, round=3}")
  H.check(p.mix.feather == 2 and p.mix.acanthus == 0 and p.mix.round == 3, "leaf and bloom weights not parsed")
end

H.done("mix")
