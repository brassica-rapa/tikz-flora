-- Shared setup for tests run with texlua from the repository root.

package.path = "./lua/?.lua;" .. package.path

-- Raster gilt (the default) at screen resolution: tests check where gold
-- goes and what it does, which no pixel count changes; test_raster.lua
-- sets its own resolutions.
require("flora.tune").gilt_dpi = 100

local H = { failures = 0 }

function H.check(cond, msg)
  if not cond then
    H.failures = H.failures + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

function H.done(name)
  if H.failures > 0 then
    io.stderr:write(string.format("%s: %d failure(s)\n", name, H.failures))
    os.exit(1)
  end
  print(name .. ": ok")
end

-- An A4 page laid out like tex/reference.tex. `last_y` is where the text stops;
-- lines at `indent_rows` start 25pt in, as list items do.
function H.page(seed, last_y, indent_rows)
  local text = { x0 = 173, y0 = 90, x1 = 544, y1 = 737 }
  local lines = {}
  local row = 0
  local y = text.y1 - 9
  while y > (last_y or text.y0) do
    row = row + 1
    local x0 = (indent_rows and indent_rows[row]) and text.x0 + 25 or text.x0
    lines[#lines + 1] = { x0 = x0, x1 = (row % 7 == 0) and 400 or text.x1, y0 = y - 2.5, y1 = y + 7.5 }
    y = y - 13.6
  end
  lines[#lines + 1] = { x0 = 538, x1 = 544, y0 = 70, y1 = 78 }  -- page number
  return {
    width = 595.28, height = 841.89, text = text, lines = lines,
    header_y = 786, seed = seed,
  }
end

return H
