local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Settings = require("flora.settings")
require("flora.orn_gild") -- registers its own kept colours

-- The setting: light, dark or a dark #rrggbb; anything else stops the
-- compile with the key's name.
do
  H.check(Settings.parse("backdrop=dark").backdrop == "dark", "backdrop=dark not accepted")
  H.check(Settings.parse("backdrop=light").backdrop == "light", "backdrop=light not accepted")
  H.check(Settings.parse("backdrop=#0E1418").backdrop == "#0e1418", "backdrop colour not accepted")
  for _, bad in ipairs({ "#ffffff", "#f0f0e8", "navy", "#12345", "" }) do
    local ok, err = pcall(Settings.parse, "backdrop=" .. bad)
    H.check(not ok and tostring(err):find("backdrop", 1, true), "backdrop=" .. bad .. " accepted")
  end
  H.check(Color.backdrop("light") == nil and Color.backdrop(nil) == nil, "light backdrop is a colour")
  local c = Color.backdrop("#0e1418")
  H.check(c and math.abs(c[1] - 14 / 255) < 1e-9 and math.abs(c[3] - 24 / 255) < 1e-9, "hex backdrop decoded wrong")
end

-- The turn-over: paper lands on the backdrop, dark ink comes out light,
-- order of lightness is reversed, hue is kept; white, metal and anything
-- painted while gilding keep their colour.
do
  local bd = Color.DARK_GROUND
  local pt = Paint.new({ backdrop = bd })
  local pal = Paint.palette
  local Lg = Color.lightness(bd)
  H.check(math.abs(Color.lightness(pt:ink(pal.paper)) - Lg) < 0.01, "paper does not land on the backdrop")
  H.check(Color.lightness(pt:ink(pal.ink)) > 0.7, "navy ink not light on dark")
  H.check(Color.lightness(pt:ink(pal.deep)) > Color.lightness(pt:ink(pal.sky)), "lightness order not reversed")
  H.check(Color.lightness(pt:ink(pal.sky)) > Color.lightness(pt:ink(pal.mist)), "lightness order not reversed for pale washes")
  H.check(Color.lightness(pt:ink(pal.mist)) > Lg + 0.02, "a pale wash vanishes into the backdrop")
  local _, _, h0 = Color.lch(pal.blue)
  local _, _, h1 = Color.lch(pt:ink(pal.blue))
  H.check(math.abs(h0 - h1) < 3, string.format("hue moved %.1f -> %.1f", h0, h1))
  H.check(pt:ink(pal.gold) == pal.gold and pt:ink(pal.white) == pal.white, "gold or white repainted")
  H.check(pt:ink(require("flora.orn_gild").umber) == require("flora.orn_gild").umber, "gilt umber repainted")
  pt.metal = 1
  H.check(pt:ink(pal.ink) == pal.ink, "ink repainted while gilding")
  H.check(pt:blend("multiply") == "multiply", "blend swapped while gilding")
  pt.metal = 0
  H.check(pt:blend("multiply") == "screen" and pt:blend("screen") == "multiply" and pt:blend(nil) == nil,
    "multiply and screen do not trade places")
  local light = Paint.new()
  H.check(light:ink(pal.ink) == pal.ink and light:blend("multiply") == "multiply", "white paper repainted")
  -- A gradient's stops are repainted as it is declared.
  pt:shading("t", { { 0, pal.deep }, { 1, pal.mist } })
  H.check(Color.lightness(pt.shadings.t[1][2]) > Color.lightness(pt.shadings.t[2][2]), "gradient stops not repainted")
end

-- A whole page on a dark backdrop: no ink darker than the backdrop, no
-- multiply left, and the gold of its ornaments unchanged.
local function colours(code)
  local out = {}
  for r, g, b in code:gmatch("(%d%.%d%d%d) (%d%.%d%d%d) (%d%.%d%d%d) [rR][gG]") do
    out[#out + 1] = { tonumber(r), tonumber(g), tonumber(b) }
  end
  return out
end
do
  local s = H.page(3, 420)
  s.layout, s.page, s.gilt = "surround", 1, "vector"
  Paint.reset_resources()
  local light = Compose.page(s):code()
  s.backdrop = "dark"
  Paint.reset_resources()
  local dark = Compose.page(s):code()
  local multiply = false
  for _, g in ipairs(Paint.resources().gs) do multiply = multiply or g.bm == "Multiply" end
  H.check(not multiply, "a dark page still multiplies")
  local screen = false
  for _, g in ipairs(Paint.resources().gs) do screen = screen or g.bm == "Screen" end
  H.check(screen, "a dark page never screens")
  local Lg = Color.lightness(Color.DARK_GROUND)
  local cols, under = colours(dark), 0
  for _, c in ipairs(cols) do
    if Color.lightness(c) < Lg - 0.03 then under = under + 1 end
  end
  -- Gilt relief keeps its own browns and shadows, which may be darker.
  H.check(#cols > 1000, "dark page has too few colours to judge")
  H.check(under / #cols < 0.02, string.format("%d of %d colours darker than the backdrop", under, #cols))
  -- Vector gilt is metal: its relief paints the same colours, as often,
  -- on both.
  local Relief = require("flora.orn_relief")
  local seen = 0
  for q = 0, 27 do
    local c = Relief.color(q / 27)
    local key = string.format("%.3f %.3f %.3f rg", c[1], c[2], c[3])
    local _, lc = light:gsub(key:gsub("%.", "%%."), "")
    local _, dc = dark:gsub(key:gsub("%.", "%%."), "")
    seen = seen + lc
    H.check(lc == dc, string.format("gilt level %d painted %d times light, %d dark", q, lc, dc))
  end
  H.check(seen > 0, "no gilt relief on the test page")
end

H.done("backdrop")
