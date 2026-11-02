local H = dofile("tests/helper.lua")
local Settings = require("flora.settings")
local Init = require("flora.init")

-- 1. Settings: baked option parses true/false/1/0/yes/no, dpi parses integers
do
  local s1 = Settings.parse("baked=true")
  H.check(s1.baked == true, "baked=true should parse as boolean true")
  local s2 = Settings.parse("baked=false")
  H.check(s2.baked == false, "baked=false should parse as boolean false")
  local s3 = Settings.parse("baked=1")
  H.check(s3.baked == true, "baked=1 should parse as boolean true")
  local s4 = Settings.parse("baked=0")
  H.check(s4.baked == false, "baked=0 should parse as boolean false")
  local ok, _ = pcall(Settings.parse, "baked=maybe")
  H.check(not ok, "baked=maybe should fail validation")

  local sd1 = Settings.parse("dpi=300")
  H.check(sd1.dpi == 300, "dpi=300 should parse as 300")
  local ok_dpi_bad, _ = pcall(Settings.parse, "dpi=not_a_number")
  H.check(not ok_dpi_bad, "invalid dpi should fail validation")
end

-- 2. Init.spec_hash: determinism and sensitivity to seed, open space (lines), layout, etc.
do
  local spec1 = {
    layout = "left", doc_seed = "1", page = 1, seed = 1,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = { { x0 = 156, x1 = 500, y0 = 700, y1 = 712 } },
  }
  local h1 = Init.spec_hash(spec1)
  H.check(type(h1) == "string" and #h1 > 0, "spec_hash should return a non-empty string")
  H.check(h1 == Init.spec_hash(spec1), "spec_hash must be deterministic")

  -- Different seed must produce different hash
  local spec_diff_seed = {
    layout = "left", doc_seed = "2", page = 1, seed = 2,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = { { x0 = 156, x1 = 500, y0 = 700, y1 = 712 } },
  }
  H.check(Init.spec_hash(spec_diff_seed) ~= h1, "different seed must produce different hash")

  -- Different open space (different lines) must produce different hash
  local spec_diff_lines = {
    layout = "left", doc_seed = "1", page = 1, seed = 1,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = {
      { x0 = 156, x1 = 500, y0 = 700, y1 = 712 },
      { x0 = 156, x1 = 450, y0 = 680, y1 = 692 },
    },
  }
  H.check(Init.spec_hash(spec_diff_lines) ~= h1, "different open space must produce different hash")

  -- Different layout must produce different hash
  local spec_diff_layout = {
    layout = "right", doc_seed = "1", page = 1, seed = 1,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = { { x0 = 156, x1 = 500, y0 = 700, y1 = 712 } },
  }
  H.check(Init.spec_hash(spec_diff_layout) ~= h1, "different layout must produce different hash")
end

-- 3. Init.find_baked: never fall back to unmatching images
do
  local set_enabled = { baked = true }
  local set_disabled = { baked = false }

  -- An arbitrary new seed/lines will not exist in cache and must return nil (never mismatching fallback)
  local spec_new = {
    layout = "left", doc_seed = "88888", page = 1, seed = 88888,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = { { x0 = 156, x1 = 300, y0 = 500, y1 = 512 } },
  }
  H.check(Init.find_baked(spec_new, set_enabled) == nil,
    "find_baked must return nil when no exact hash match exists (no fallback to mismatching presaved flowers)")
  H.check(Init.find_baked(spec_new, set_disabled) == nil,
    "find_baked must return nil when baked=false")
end

-- 4. Auto-baking and cache-hit verification via Init.bake_page and Init.find_baked
do
  local test_spec = {
    layout = "left", doc_seed = "777", page = 1, seed = 777,
    width = 595.28, height = 841.89,
    text = { x0 = 156, y0 = 90, x1 = 538, y1 = 740 },
    lines = {},
    dpi = 72, -- low dpi for fast test
  }
  local hash = Init.spec_hash(test_spec)
  local target_png = string.format(".flora-cache/flora-left-s777-p1-%s.png", hash)

  -- Ensure it does not exist initially
  os.remove(target_png)
  H.check(Init.find_baked(test_spec, { baked = true }) == nil, "initially test image should not be found")

  -- Bake the page
  local ok, res = Init.bake_page(test_spec, target_png, test_spec.dpi)
  H.check(ok == true, "bake_page should succeed: " .. tostring(res))

  -- Verify it exists and is a valid file
  local fh = io.open(target_png, "rb")
  H.check(fh ~= nil, "target_png should exist on disk")
  if fh then
    local header = fh:read(8)
    fh:close()
    H.check(header == "\137PNG\r\n\026\n", "target_png must have valid PNG signature")
  end

  -- Now find_baked must find this exact cached file
  local found = Init.find_baked(test_spec, { baked = true })
  H.check(found ~= nil, "find_baked should now find cached image")
  if found then
    H.check(found:find(hash) ~= nil, "found image must match exact spec hash")
  end

  -- Clean up test file
  os.remove(target_png)
end

-- 5. Settings: colourway / colorway preset parsing
do
  local s_rose = Settings.parse("colourway=rose")
  H.check(s_rose.palette and s_rose.palette.hero == "tsutsuji", "colourway=rose should set hero=tsutsuji")
  H.check(s_rose.palette.blooms == "hana-ikada", "colourway=rose blooms should be hana-ikada")

  local s_colorway = Settings.parse("colorway=rose")
  H.check(s_colorway.palette and s_colorway.palette.hero == "tsutsuji", "colorway (US spelling) should work")

  local s_ember = Settings.parse("colourway=ember")
  H.check(s_ember.palette and s_ember.palette.hero == "yu-yake", "colourway=ember should set hero=yu-yake")

  local s_plum = Settings.parse("colourway=plum")
  H.check(s_plum.palette and s_plum.palette.hero == "murasaki-shikibu", "colourway=plum should set hero=murasaki-shikibu")

  local s_spring = Settings.parse("colourway=spring")
  H.check(s_spring.palette and s_spring.palette.hero == "tsutsuji", "colourway=spring should set hero=tsutsuji")
  H.check(s_spring.palette.leaves == "chiku-rin", "colourway=spring leaves should be chiku-rin")

  local s_summer = Settings.parse("colourway=summer")
  H.check(s_summer.palette and s_summer.palette.hero == "asa-gao", "colourway=summer should set hero=asa-gao")
  H.check(s_summer.palette.blooms == "ajisai", "colourway=summer blooms should be ajisai")

  local s_fall = Settings.parse("colourway=fall")
  H.check(s_fall.palette and s_fall.palette.hero == "momiji", "colourway=fall should set hero=momiji")
  H.check(s_fall.palette.blooms == "yama-budo", "colourway=fall blooms should be yama-budo")

  local s_autumn = Settings.parse("colourway=autumn")
  H.check(s_autumn.palette and s_autumn.palette.hero == "momiji", "colourway=autumn alias should work")

  local s_winter = Settings.parse("colourway=winter")
  H.check(s_winter.palette and s_winter.palette.hero == "fuyu-syogun", "colourway=winter should set hero=fuyu-syogun")
  H.check(s_winter.palette.blooms == "kiri-same", "colourway=winter blooms should be kiri-same")

  local s_orig = Settings.parse("colourway=original")
  H.check(s_orig.palette and s_orig.palette.hero == "look", "colourway=original should set hero=look")

  -- Overriding individual palette items on top of colourway
  local s_over = Settings.parse("colourway=rose, palette={hero=kon-peki}")
  H.check(s_over.palette.hero == "kon-peki", "palette override should replace hero")
  H.check(s_over.palette.blooms == "hana-ikada", "palette override should retain other colourway inks")

  -- User exact snippet from prompt
  local user_snippet = "layout=left, seed=37, density=0.6, mix={bee=1, butterfly=1, bird=1, snail=1}, colourway=rose"
  local s_user = Settings.parse(user_snippet)
  H.check(s_user.layout == "left", "user snippet layout should be left")
  H.check(s_user.seed == "37", "user snippet seed should be 37")
  H.check(s_user.mix and s_user.mix.density == 0.6, "user snippet density should be 0.6")
  H.check(s_user.mix.bee == 1 and s_user.mix.butterfly == 1, "user snippet mix should have visitors")
  H.check(s_user.palette and s_user.palette.hero == "tsutsuji", "user snippet colourway should set palette")

  -- Invalid colourway fails validation
  local ok_bad, _ = pcall(Settings.parse, "colourway=neon")
  H.check(not ok_bad, "invalid colourway should fail")
end

H.done("test_baked")
