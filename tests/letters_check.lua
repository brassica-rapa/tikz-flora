-- Checks run by tests/letters.tex: box 0 holds a word set plainly, box 2
-- the same word as \floraletters, box 4 arched, box 6 a paragraph holding
-- it.
local SP = 65536
local function fail(msg) error("letters test: " .. msg) end
local plain, straight, arched = tex.box[0], tex.box[2], tex.box[4]

-- The lettering keeps the word's advance width (to the 0.001pt it is
-- written with), so it sets like text.
if math.abs(straight.width - plain.width) > 0.01 * SP then
  fail(string.format("lettering is %.2fpt wide, the word %.2fpt", straight.width / SP, plain.width / SP))
end
-- It drew the outlines: the picture's literal holds curves (c) and fills.
local literal
for n in node.traverse(straight.head) do
  local function find(h)
    for m in node.traverse(h) do
      if m.id == node.id("whatsit") and m.data and m.data:find(" c ", 1, true) then literal = m.data end
      if m.head then find(m.head) end
    end
  end
  if n.head then find(n.head) end
end
if not literal then fail("no outline curves were drawn") end
-- The shaded shadow falls below the baseline's descent-free capitals.
if straight.depth <= plain.depth then fail("the shadow did not deepen the box") end
-- An arch raises the middle above the straight word.
if arched.height <= straight.height + 2 * SP then
  fail(string.format("arched height %.2fpt is no taller than straight %.2fpt", arched.height / SP, straight.height / SP))
end
-- The measurer sees the lettering as ink.
local boxes = require("flora.measure").boxes(6, 800)
if #boxes ~= 1 or boxes[1].x1 - boxes[1].x0 < plain.width / SP - 2 then
  fail("the lettering was not measured as ink (" .. #boxes .. " boxes)")
end
texio.write_nl("term and log", "letters: ok")
