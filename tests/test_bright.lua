-- The +bright ink modifier: parsing, fitting and the yellow special case.
package.path = "./lua/?.lua;" .. package.path
local Inks = require("flora.inks")
local Color = require("flora.color")
local Settings = require("flora.settings")
local Mix = require("flora.mix")
local function check(c, m) if not c then print("FAIL: " .. m) os.exit(1) end end
check(Inks.bright["gold+bright"] == nil and Inks.valid("gold+bright"), "group+bright valid")
check(Inks.bright["daikokuten+bright"] and not Inks.bright["daikokuten"], "bright only with suffix")
check(Inks.ramps["ama-iro+bright"] == Inks.ramps["ama-iro"], "same ramp")
check(not Inks.valid("nonsense+bright"), "unknown ink rejected")
check(Color.fit("daikokuten", 0.3) == 0.3 and Color.fit("daikokuten+bright", 0.3) > 0.7, "fit lifts only bright")
local r = { int = function() return 1 end }
check(Color.ink_for(r, "gold+bright") == "daikokuten+bright", "group member keeps suffix")
check(Color.is_yellow("daikokuten+bright") and not Color.is_yellow("ama-iro+bright") and not Color.is_yellow("daikokuten"), "is_yellow")
local s = Settings.parse("palette={hero=gold+bright, blooms=random+bright}")
check(s.palette.hero == "gold+bright", "settings accept +bright")
check(not pcall(Settings.parse, "palette={hero=gold+brightish}"), "typo rejected")
check(Mix.resolve({ blooms = "random+bright" }, 3, 0).blooms:match("%+bright$"), "random+bright resolves")
local base = Color.ink_rgb("ama-iro", 0.3)
local lit = Color.ink_rgb("ama-iro+bright", 0.3)
check(Color.lightness(lit) > Color.lightness(base) + 0.2, "bright blue is lighter")
print("bright: ok")
