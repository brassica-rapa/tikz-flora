-- Document settings from \florasetup and \florathispage: a key=value list,
-- parsed and checked here so mistakes are reported with the key's name.
--
--   layout    left, right, centered, split, title or surround (frames.lua)
--   seed      a number, or random
--   mix       weights per kind of growth, e.g. mix={lily=2, umbel=0}
--             (mix.lua lists the kinds)
--   density   how full the border grows (mix.density); below 1 is airier
--   visitors  the weight of every visitor at once (bee, butterfly, bird,
--             snail); mix={bee=0} after it still turns one off
--   palette   what paints each part, e.g. palette={leaves=green,
--             hero=kon-peki}: look, an ink group, one ink (inks.lua), or
--             random for one ink picked per page
--   flower    the bloom style of the hero and the blooms (flower.lua): fan,
--             round, soft, obovate, wedge, cross (a crucifer) or buttercup
--   hero      what crowns the main stem: bloom (the default), or a painted
--             raceme, corymb or panicle of blooms (head.lua)
--   petals    how many petals every bloom has, 3 to 12; florets of an
--             inflorescence follow it too
--   colourway a preset palette: rose, ember, or plum (or colorway)
--   spin      a number that re-picks the random inks; the shapes stay
--   ornaments weights per ornament kind, e.g. ornaments={moon=2, night=0}
--             (ornaments.lua registers the kinds; each slot picks one)

local M = {}

local Frames = require("flora.frames")
local Tune = require("flora.tune")
local Inks = require("flora.inks")
local Mix = require("flora.mix")
local Orn = require("flora.ornaments")
local Flower = require("flora.flower")
local Head = require("flora.head")

-- Key name -> function(value string) returning the parsed value, or nil
-- and a message.
local keys = {}

function M.define(name, parse)
  keys[name] = parse
end

M.define("layout", function(v)
  if Frames.layouts[v] then return v end
  return nil, "layout must be one of left, right, centered, split, title, surround"
end)

M.define("seed", function(v)
  if v == "random" or tonumber(v) then return v end
  return nil, "seed must be a number or random"
end)

local function weight(v)
  local n = tonumber(v)
  if n and n >= 0 and n <= 10 then return n end
end

local function known(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return table.concat(out, ", ")
end

M.define("density", function(v)
  local n = weight(v)
  if n then return n end
  return nil, "density must be a number from 0 to 10"
end)

-- A shorthand for every visitor's weight.
M.define("visitors", function(v)
  local n = weight(v)
  if n then return n end
  return nil, "visitors must be a number from 0 to 10"
end)

M.define("mix", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local k, w = kv[1], weight(kv[2])
    if Tune.mix[k] == nil then return nil, "no kind \"" .. k .. "\" (kinds: " .. known(Tune.mix) .. ")" end
    if not w then return nil, k .. " needs a weight from 0 to 10" end
    t[k] = w
  end
  return t
end)

M.define("ornaments", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local k, w = kv[1], weight(kv[2])
    if not Orn.kinds[k] then return nil, "no ornament \"" .. k .. "\" (kinds: " .. known(Orn.kinds) .. ")" end
    if not w then return nil, k .. " needs a weight from 0 to 10" end
    t[k] = w
  end
  return t
end)

M.define("palette", function(v)
  local t = {}
  for _, kv in ipairs(M.parse_list(v)) do
    local part, ink = kv[1], kv[2]
    if Tune.color.palette[part] == nil then
      return nil, "no part \"" .. part .. "\" (parts: " .. known(Tune.color.palette) .. ")"
    end
    if not (ink == "look" or ink == "random" or Inks.groups[ink] or Inks.ramps[ink]) then
      return nil, "\"" .. tostring(ink) .. "\" is not look, random, an ink group or an ink name"
    end
    t[part] = ink
  end
  return t
end)

M.define("flower", function(v)
  if Flower.styles[v] then return v end
  return nil, "no flower \"" .. v .. "\" (flowers: " .. known(Flower.styles) .. ")"
end)

M.define("hero", function(v)
  for _, k in ipairs(Head.kinds) do
    if k == v then return v end
  end
  return nil, "hero must be one of " .. table.concat(Head.kinds, ", ")
end)

M.define("petals", function(v)
  local n = tonumber(v)
  if n and n == math.floor(n) and n >= 3 and n <= 12 then return n end
  return nil, "petals must be a whole number from 3 to 12"
end)
local colourways = {
  rose = {
    hero = "tsutsuji",
    blooms = "hana-ikada",
    leaves = "blue-grey",
    leaflets = "fukagawa-nezu",
    stems = "take-sumi",
    sprays = "kosumosu",
    ghost = "hana-ikada",
    cartouche = "tsuki-yo",
  },
  ember = {
    hero = "yu-yake",
    blooms = "momiji",
    leaves = "green",
    leaflets = "hotaru-bi",
    stems = "yama-guri",
    sprays = "to-ro",
    ghost = "benzaiten",
    cartouche = "fuyu-gaki",
  },
  plum = {
    hero = "murasaki-shikibu",
    blooms = "yama-budo",
    leaves = "teal",
    leaflets = "chiku-rin",
    stems = "yama-guri",
    sprays = "edo-murasaki",
    ghost = "rikka",
    cartouche = "ku-jaku",
  },
  spring = {
    hero = "tsutsuji",
    blooms = "hana-ikada",
    leaves = "chiku-rin",
    leaflets = "hotaru-bi",
    stems = "tsukushi",
    sprays = "syun-gyo",
    ghost = "hana-ikada",
    cartouche = "sui-gyoku",
  },
  summer = {
    hero = "asa-gao",
    blooms = "ajisai",
    leaves = "shin-ryoku",
    leaflets = "chiku-rin",
    stems = "yama-guri",
    sprays = "hotaru-bi",
    ghost = "ama-iro",
    cartouche = "ku-jaku",
  },
  fall = {
    hero = "momiji",
    blooms = "yama-budo",
    leaves = "ina-ho",
    leaflets = "to-ro",
    stems = "yama-guri",
    sprays = "yu-yake",
    ghost = "fuyu-gaki",
    cartouche = "take-sumi",
  },
  winter = {
    hero = "fuyu-syogun",
    blooms = "kiri-same",
    leaves = "blue-grey",
    leaflets = "fukagawa-nezu",
    stems = "take-sumi",
    sprays = "syo-ro",
    ghost = "rikka",
    cartouche = "tsuki-yo",
  },
  original = {
    hero = "look",
    blooms = "look",
    leaves = "blue",
    leaflets = "blue",
    stems = "chiku-rin",
    sprays = "look",
    ghost = "look",
    cartouche = "look",
  },
}
colourways.autumn = colourways.fall
colourways.default = colourways.original
colourways.blue = colourways.original
M.colourways = colourways

local function parse_colourway(v)
  local norm = v:lower():gsub("%s+", "")
  local pal = colourways[norm]
  if pal then
    local copy = {}
    for k, ink in pairs(pal) do copy[k] = ink end
    return copy
  end
  return nil, "must be one of rose, ember, plum, spring, summer, fall, winter, original"
end

M.define("colourway", parse_colourway)
M.define("colorway", parse_colourway)

M.define("spin", function(v)
  local n = tonumber(v)
  if n and n == math.floor(n) and n >= 0 then return n end
  return nil, "spin must be a whole number"
end)

M.define("baked", function(v)
  if v == "true" or v == "1" or v == "yes" then return true end
  if v == "false" or v == "0" or v == "no" then return false end
  return nil, "baked must be true or false"
end)

M.define("dpi", function(v)
  local n = tonumber(v)
  if n and n >= 50 and n <= 1200 then return n end
  return nil, "dpi must be a number between 50 and 1200"
end)

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split "a=1, b={x=2, y=3}" at top-level commas into {name, value} pairs;
-- braces around a value are removed. A key without "=" has value nil.
function M.parse_list(s)
  local out, depth, start = {}, 0, 1
  local function take(piece)
    piece = trim(piece)
    if piece == "" then return end
    local k, v = piece:match("^([^=]-)%s*=%s*(.*)$")
    if not k then
      out[#out + 1] = { trim(piece), nil }
      return
    end
    v = trim(v)
    local inner = v:match("^{(.*)}$")
    out[#out + 1] = { trim(k), inner and trim(inner) or v }
  end
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == "{" then depth = depth + 1
    elseif ch == "}" then depth = depth - 1
      if depth < 0 then error("unbalanced braces in \"" .. s .. "\"") end
    elseif ch == "," and depth == 0 then
      take(s:sub(start, i - 1))
      start = i + 1
    end
  end
  if depth ~= 0 then error("unbalanced braces in \"" .. s .. "\"") end
  take(s:sub(start))
  return out
end

-- Parse a key=value list into a settings table. Errors name the key.
function M.parse(s)
  local t = {}
  for _, kv in ipairs(M.parse_list(s)) do
    local k, v = kv[1], kv[2]
    local parse = keys[k]
    if not parse then
      local known = {}
      for name in pairs(keys) do known[#known + 1] = name end
      table.sort(known)
      error(string.format("unknown key \"%s\" (known keys: %s)", k, table.concat(known, ", ")))
    end
    if v == nil then error(string.format("key \"%s\" needs a value", k)) end
    local val, msg = parse(v)
    if val == nil then error(string.format("%s: %s (got \"%s\")", k, msg, v)) end
    if k == "density" then
      t.mix = M.merge({ mix = t.mix }, { mix = { density = val } }).mix
    elseif k == "visitors" then
      local m = {}
      for _, name in ipairs(Mix.visitors) do m[name] = val end
      t.mix = M.merge({ mix = t.mix }, { mix = m }).mix
    elseif k == "colourway" or k == "colorway" then
      t.palette = M.merge({ palette = t.palette }, { palette = val }).palette
    else
      t[k] = M.merge({ [k] = t[k] }, { [k] = val })[k]
    end
  end
  return t
end

-- Merge settings table `over` onto `base`, returning a new table. Table
-- values (such as mix) merge key by key.
function M.merge(base, over)
  local t = {}
  for k, v in pairs(base or {}) do t[k] = v end
  for k, v in pairs(over or {}) do
    if type(v) == "table" and type(t[k]) == "table" then
      local m = {}
      for a, b in pairs(t[k]) do m[a] = b end
      for a, b in pairs(v) do m[a] = b end
      t[k] = m
    else
      t[k] = v
    end
  end
  return t
end

return M
