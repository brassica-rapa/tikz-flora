-- Checks run by tests/measure.tex against box register 0, which holds two
-- lines set in a 200pt-wide vbox, the second indented by 50pt, and a
-- 40pt box marked as ink.

local boxes, marks = require("flora.measure").boxes(0, 600)
local function fail(msg) error("measure test: " .. msg) end

if #boxes ~= 3 then fail("expected 2 line boxes and an ink box, got " .. #boxes) end
local origin = (4736286 + tex.hoffset) / 65536
local a, b = boxes[1], boxes[2]
if math.abs(a.x0 - origin) > 0.5 then
  fail("first line starts at " .. a.x0 .. ", expected " .. origin)
end
if math.abs(b.x0 - (origin + 50)) > 0.5 then
  fail("indented line starts at " .. b.x0 .. ", expected " .. origin + 50)
end
if not (a.y0 > b.y1 - 2) then fail("first line is not above the second") end
if not (a.x1 > a.x0 + 30 and a.x1 < origin + 200) then
  fail("first line width " .. (a.x1 - a.x0))
end
local top = 600 - (4736286 + tex.voffset) / 65536
if a.y1 > top + 0.01 or a.y1 < top - 12 then
  fail("first line top " .. a.y1 .. " vs box top " .. top)
end
-- The box marked as ink counts whole, though it holds no glyph or rule.
local c = boxes[3]
if math.abs(c.x1 - c.x0 - 40) > 0.01 or math.abs(c.y1 - c.y0 - 15) > 0.01 or c.y1 > b.y0 then
  fail(string.format("ink box measured %.2f x %.2f at %.1f", c.x1 - c.x0, c.y1 - c.y0, c.y1))
end
-- The marks keep their names, and lie above and below the first line.
if not (marks["title-start"] and marks["title-end"]) then
  local names = {}
  for k in pairs(marks) do names[#names + 1] = string.format("%q", k) end
  fail("marks lost their names: " .. table.concat(names, ", "))
end
if not (marks["title-start"] >= a.y1 - 0.01 and marks["title-end"] <= a.y0 + 0.01 and marks["title-end"] >= b.y1 - 0.01) then
  fail(string.format("marks at %.1f and %.1f do not bracket the first line (%.1f to %.1f)",
    marks["title-start"], marks["title-end"], a.y0, a.y1))
end
texio.write_nl("term and log", "measure: ok")
