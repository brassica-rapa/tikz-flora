-- Prints every option the package offers (lua/flora/catalog.lua) as JSON,
-- for the site's guide:
--
--   texlua tools/catalog.lua > site/public/bake/catalog.json
--
-- Run from the repository root.

package.path = "./lua/?.lua;" .. package.path
local Catalog = require("flora.catalog")
io.write(Catalog.json(Catalog.build()), "\n")
