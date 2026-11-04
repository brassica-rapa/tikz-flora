-- The site's renderers (flora's scene reader, via site/src/lib/draw.js)
-- replay the PDF content stream paint.lua writes, and know only the
-- operators listed in site/src/lib/scene-ops.json (site/tests/e2e.mjs
-- holds flora's OPERATORS to that list). Every operator a page or the ornament
-- gallery uses must be on that list, and every named state or pattern the
-- stream uses must be in the scene's resources (pdfout.lua M.scene).
local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Pdf = require("flora.pdfout")
local Gallery = require("flora.gallery")

local f = assert(io.open("site/src/lib/scene-ops.json"))
local known = {}
for op in f:read("a"):gmatch('"([^"]+)"') do known[op] = true end
f:close()
H.check(known.f and known.S and known.q, "scene-ops.json did not parse")

local function check(label, pt, w, h)
  local scene = Pdf.scene(pt, w, h)
  local unknown, missing = {}, {}
  for tok in pt:body():gmatch("%S+") do
    local c = tok:sub(1, 1)
    if c == "/" then
      local name = tok:sub(2)
      if name ~= "Pattern" and not scene:find('"' .. name .. '":', 1, true) then missing[name] = true end
    elseif not tok:match("^[-%d.]") and not known[tok] then
      unknown[tok] = true
    end
  end
  for op in pairs(unknown) do H.check(false, label .. " uses operator " .. op .. ", which flora's scene reader does not know") end
  for name in pairs(missing) do H.check(false, label .. " uses /" .. name .. ", missing from the scene's resources") end
  H.check(scene:find('"content":"q ', 1, true), label .. ": the scene does not carry the content stream")
end

for _, layout in ipairs({ "left", "right", "centered", "surround" }) do
  for seed = 1, 2 do
    local spec = H.page(seed)
    spec.layout = layout
    spec.mix = { bee = 1, butterfly = 1, bird = 1, snail = 1 }
    Paint.reset_resources()
    check(layout .. " page, seed " .. seed, Compose.page(spec), spec.width, spec.height)
  end
end
-- The title layouts add clipped hatching, curved frames and gilt bands.
for _, layout in ipairs({ "flank", "wreath", "bouquet", "scrollwork" }) do
  local spec = H.page(1, 420)
  spec.layout, spec.page = layout, 1
  Paint.reset_resources()
  check(layout .. " page", Compose.page(spec), spec.width, spec.height)
end
do
  Paint.reset_resources()
  local pt, _, w, h = Gallery.sheet(nil, 2)
  check("gallery", pt, w, h)
end
-- Raster gilt adds images (cm, Do and the image's name).
do
  local spec = H.page(3)
  spec.layout, spec.gilt, spec.gilt_dpi = "surround", "raster", 72
  Paint.reset_resources()
  local pt = Compose.page(spec)
  H.check(pt:body():find(" Do "), "a raster gilt page drew no image")
  check("raster gilt page", pt, spec.width, spec.height)
end

H.done("scene ops")
