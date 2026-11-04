-- Writes the painted page for a fixed spec to arg[1], so the output under
-- texlua (Lua 5.3, as in LuaLaTeX) can be compared byte for byte with Lua
-- 5.4 (the browser mixer's wasmoon). `just test-lua54` runs it.
local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local f = assert(io.open(arg[1], "wb"))
-- The wreath's curved frames and the bouquet's ribbons run through math
-- the other layouts do not (oval.lua's table and Newton steps).
local cases = { { 3, nil, nil }, { 4, "surround", { bee = 1, bird = 1, butterfly = 1, snail = 1 } }, { 5, "wreath", nil }, { 6, "bouquet", nil } }
for _, case in ipairs(cases) do
  Paint.reset_resources()
  local s = H.page(case[1], 420)
  s.layout, s.mix, s.page = case[2], case[3], 1
  f:write(Compose.page(s):code(), "\n")
  s.grow = 0.5
  Paint.reset_resources()
  f:write(Compose.page(s):code(), "\n")
end
-- A dark backdrop repaints every ink through OKLCH (color.lua), math
-- the light page never runs.
Paint.reset_resources()
do
  local s = H.page(3, 420)
  s.layout, s.page, s.backdrop = "surround", 1, "dark"
  f:write(Compose.page(s):code(), "\n")
end
-- Raster gilt, in both looks: the page and every image it computed,
-- byte for byte.
for _, env in ipairs({ "studio", "mirror" }) do
  Paint.reset_resources()
  local s = H.page(3, 420)
  s.layout, s.page, s.gilt, s.gilt_dpi, s.gilt_env = "surround", 1, "raster", 200, env
  f:write(Compose.page(s):code(), "\n")
  for _, x in ipairs(Paint.resources().xobjects) do
    f:write(x[1], " ", x.image.w, "x", x.image.h, "\n", x.image.rgb, x.image.alpha, "\n")
  end
end
f:close()
