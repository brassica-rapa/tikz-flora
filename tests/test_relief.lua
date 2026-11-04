local H = dofile("tests/helper.lua")
local Relief = require("flora.orn_relief")
local Paint = require("flora.paint")
local G = require("flora.geom")

-- Gold mirrors its studio: an edge facing the light (upper left) is
-- brighter than one facing away, at every bevel tilt, and the flat top
-- (no tilt) is the mid gold it mirrors straight ahead.
do
  for _, th in ipairs({ 0.4, 0.8, 1.2 }) do
    local lit, away = Relief.mirror(-0.6, 0.8, th), Relief.mirror(0.6, -0.8, th)
    H.check(lit > away + 0.2, string.format("tilt %.1f: lit edge %.2f, far edge %.2f", th, lit, away))
  end
  H.check(math.abs(Relief.mirror(1, 0, 0) - 0.52) < 1e-9, "the flat top is not mid gold")
end

-- The bevel's strips tile the band between a shape's outline and its
-- innermost ring exactly, whichever way the outline winds: a dropped strip
-- or one wound the other way would leave a hole in the gold.
do
  local function circle(r, cw)
    local pts = {}
    for k = 0, 59 do
      local a = (cw and -1 or 1) * k * 2 * math.pi / 60
      pts[#pts + 1] = { r * math.cos(a), r * math.sin(a) }
    end
    return pts
  end
  for _, cw in ipairs({ false, true }) do
    local buckets = {}
    local poly = circle(10, cw)
    local top = Relief.bevel(poly, buckets)
    local strips = 0
    for _, list in pairs(buckets) do
      for _, s in ipairs(list) do
        H.check(Relief.area(s) > 0, "a bevel strip winds backward")
        strips = strips + Relief.area(s)
      end
    end
    local band = math.abs(Relief.area(poly)) - math.abs(Relief.area(top))
    H.check(math.abs(strips - band) < band * 0.01, string.format("strips cover %.2f of a %.2f band (cw %s)", strips, band, tostring(cw)))
  end
end

-- Light is the page's: in a mirrored frame the bright bevel still lies on
-- the shape's upper-left side. Each colour level's fill records where it
-- landed, and the brightest level must sit up and to the left of the
-- darkest.
do
  for _, fx in ipairs({ 1, -1 }) do
    Paint.reset_resources()
    local pt = Paint.new({ backend = "pdf" })
    pt:frame(function(x, y) return 300 + fx * (x - 300), y end)
    local fills = {}
    local orig = pt.fill
    pt.fill = function(self, cmds, rgb, op, opts)
      if opts and opts.many and op == 1 then
        local sx, sy, n = 0, 0, 0
        for _, c in ipairs(cmds) do for _, k in ipairs(c) do if k[1] ~= "z" then sx, sy, n = sx + k[2], sy + k[3], n + 1 end end end
        fills[#fills + 1] = { lum = rgb[1] + rgb[2] + rgb[3], x = sx / n, y = sy / n }
      end
      return orig(self, cmds, rgb, op, opts)
    end
    Relief.paint(pt, { { { "o", 100, 100, 20 } } }, {})
    table.sort(fills, function(a, b) return a.lum < b.lum end)
    local dark, bright = fills[1], fills[#fills]
    H.check(bright.x < dark.x and bright.y > dark.y,
      string.format("flip %d: brightest gold at (%.0f, %.0f), darkest at (%.0f, %.0f)", fx, bright.x, bright.y, dark.x, dark.y))
  end
end

H.done("relief")
