-- animals=painted: the setting, its hash, and that classic stays untouched.
local H = dofile("tests/helper.lua")
local Compose = require("flora.compose")
local Paint = require("flora.paint")
local Settings = require("flora.settings")
local Visitor = require("flora.visitor")
local Init = require("flora.init")

local ON = { bee = 3, butterfly = 0, bird = 3, snail = 0 }

local function page(seed, animals)
  local s = H.page(seed)
  s.mix = ON
  s.animals = animals
  Paint.reset_resources()
  return Compose.page(s):code(), s
end

H.check(Settings.parse("animals=painted").animals == "painted", "animals=painted should parse")
H.check(not pcall(Settings.parse, "animals=cartoon"), "an unknown animals style should be rejected")

-- Classic is the default: naming it changes nothing, painted does.
local default = page(5)
H.check(default == page(5, "classic"), "animals=classic should not change the page")
H.check(default ~= page(5, "painted"), "animals=painted should change the page")

-- The style is restored after a page, and an error does not leave it set.
page(5, "painted")
H.check(Visitor.animals == "classic", "painted should be restored to classic after a page")
H.check(not pcall(Visitor.with_animals, "painted", function() error("boom") end), "an error should pass through")
H.check(Visitor.animals == "classic", "painted should be restored after an error")

-- Baked pages are keyed by it.
local _, s = page(5)
local _, sp = page(5, "painted")
H.check(Init.spec_hash(s) ~= Init.spec_hash(sp), "animals should change a baked page's hash")
local _, sc = page(5, "classic")
H.check(Init.spec_hash(s) == Init.spec_hash(sc), "classic should hash like the default")
print("animals: ok")
