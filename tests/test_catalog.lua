local H = dofile("tests/helper.lua")
local Catalog = require("flora.catalog")
local Settings = require("flora.settings")
local Frames = require("flora.frames")
local Tune = require("flora.tune")
local Look = require("flora.gilt_look")
local Letters = require("flora.letters")
local Orn = require("flora.ornaments")

local c = Catalog.build()

-- Every key the settings parser accepts is described, once, and nothing
-- else: a key added without a description, or a description left behind
-- by a removed key, fails here.
do
  local described = {}
  for _, s in ipairs(c.settings) do
    H.check(not described[s.key], "setting described twice: " .. s.key)
    described[s.key] = true
    H.check(s.values ~= "" and s.about ~= "", "setting without values or effect: " .. s.key)
  end
  for _, k in ipairs(Settings.defined()) do H.check(described[k], "setting not in the catalog: " .. k) end
  for k in pairs(described) do
    local found = false
    for _, d in ipairs(Settings.defined()) do found = found or d == k end
    H.check(found, "catalog describes a setting the parser does not accept: " .. k)
  end
end

-- Every layout, mix kind, ornament kind, gilt look key and lettering
-- style is listed, with its description.
do
  H.check(#c.layouts == #Frames.order, "layouts missing from the catalog")
  for _, l in ipairs(c.layouts) do H.check(l.about and l.about ~= "", "layout without a description: " .. l.name) end
  local kinds = {}
  for _, g in ipairs(c.mix) do
    for _, k in ipairs(g.kinds) do
      H.check(not kinds[k.key], "mix kind in two groups: " .. k.key)
      kinds[k.key] = true
      local d = Tune._doc["mix." .. k.key]
      H.check(d and d[1] and d[2], "mix kind without a label and description in tune.lua's docs: " .. k.key)
    end
  end
  for k in pairs(Tune.mix) do H.check(kinds[k], "mix kind not in any group: " .. k) end
  local orn = 0
  for _, s in ipairs(c.ornaments) do orn = orn + #s.kinds end
  H.check(orn == #Orn.order, string.format("catalog lists %d ornament kinds of %d", orn, #Orn.order))
  local gk = {}
  for _, k in ipairs(c.gilt.keys) do
    gk[k.key] = true
    H.check(k.min < k.max, "gilt key with an empty range: " .. k.key)
    for look, v in pairs(k.defaults) do
      H.check(v >= k.min and v <= k.max, string.format("%s's default in %s is outside its range", k.key, look))
    end
  end
  for k in pairs(Look.keys) do H.check(gk[k], "gilt look key not in the catalog: " .. k) end
  for k in pairs(Look.keys) do H.check(Tune._doc[k], "gilt look key without docs in tune.lua: " .. k) end
  H.check(#c.letters.styles == #Letters.style_order, "lettering styles missing")
  for s in pairs(Letters.styles) do
    local found = false
    for _, x in ipairs(c.letters.styles) do found = found or x.name == s end
    H.check(found, "lettering style not in the catalog: " .. s)
  end
  H.check(c.letters.inks.black:match("^#%x%x%x%x%x%x$") and c.letters.inks["kon-peki"], "lettering inks missing")
end

-- JSON: strings escaped, arrays kept in order, object keys sorted.
do
  H.check(Catalog.json({ "a\"b\\c\nd", 1, 0.5 }) == '["a\\"b\\\\c\\nd",1,0.5]', "JSON string or array encoded wrongly")
  H.check(Catalog.json({ b = true, a = {} }) == '{"a":{},"b":true}', "JSON object encoded wrongly")
  local s = Catalog.json(c)
  H.check(#s > 2000 and s:sub(1, 1) == "{", "catalog JSON missing")
end

H.done("catalog")
