-- LotJ Plugin DEV (QA-07): a separate development plugin that bundles the
-- production code with feature scenarios and runs them inside MudForge.
-- Install it only in a throwaway world with the release plugin turned off;
-- see scripts/dev/install_dev_plugin.py. Never part of the release ZIP.
plugin = {
  id          = "lotj-dev",
  name        = "LotJ Plugin DEV",
  version     = "0.1.0",
  author      = "Mindcloud Team",
  description = "Runs the LOTJ Companion feature scenarios inside MudForge. Never connects to the MUD.",
}
local devPlugin = plugin

loadModule("dev/harness.lua") -- must run first: it replaces the host ports
loadModule("src/lotj.lua")    -- the production entry point, hooks included
plugin = devPlugin

local productionInit = init

local function runAll(filter)
  return LotjDev.run(LotjDev.scenarios(), filter)
end

function init()
  productionInit()
  registerCommand("lotjdev", function(args)
    local filter = (args or ""):match("^%s*(.-)%s*$")
    local results = runAll(filter)
    return results.summary or "LOTJDEV RUNNING (summary follows)"
  end, "Run the LotJ DEV feature scenarios (optional name filter)")
  runAll()
end
