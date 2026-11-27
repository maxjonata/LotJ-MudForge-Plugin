-- Entry point (src/lotj.lua) wiring through the fake host: theme, status bar
-- GMCP routing, timer fallback, lifecycle hooks and scaffolding handlers.
local fake_host = dofile("tests/support/fake_host.lua")

do -- init is passive and registers the GMCP packages the plugin reads
  local host = fake_host.new()
  host.loadPlugin()
  assert(#host.sends == 0, "init must not send")
  for _, package in ipairs({ "Char.Vitals", "Ship.Info", "Ship.System", "Char.Enemy", "Char.Chat" }) do
    assert(host.gmcpHandlers[package], "missing GMCP handler: " .. package)
  end
  assert(host.themes[1].id == "lotj-holocron" and host.activeTheme == "lotj-holocron")
  print("PASS: init registers GMCP handlers and applies the theme without sending")
end

do -- theme registration failure leaves the user's theme alone
  local host = fake_host.new({ themeId = false })
  host.loadPlugin()
  assert(host.activeTheme == nil and host.count("setTheme") == 0)
  print("PASS: no setTheme when registerTheme fails")
end

do -- Char.Vitals reaches the status bar, Force only with a positive maxMana
  local host = fake_host.new()
  host.loadPlugin()
  host.gmcp("Char.Vitals", { hp = 10, maxHp = 20, move = 5, maxMove = 9, mana = 0, maxMana = 0, wimpy = 3 })
  local values = host.last("lotj-status-bar", "vitals").values
  assert(values.hp == 10 and values.maxHp == 20 and values.move == 5 and values.maxMove == 9)
  assert(values.force == nil and values.mana == 0 and values.maxMana == 0 and values.wimpy == 3)
  host.gmcp("Char.Vitals", { hp = 1, maxHp = 2, move = 3, maxMove = 4, mana = 7, maxMana = 8 })
  values = host.last("lotj-status-bar", "vitals").values
  assert(values.force == 7 and values.maxForce == 8 and values.wimpy == nil)
  host.gmcp("Char.Vitals", { hp = 1, maxHp = 2, move = 3, maxMove = 4 })
  values = host.last("lotj-status-bar", "vitals").values
  assert(values.mana == nil and values.force == nil, "no mana fields, no Force bar")
  print("PASS: vitals route to the status bar with Force gated on maxMana")
end

do -- Char.Enemy strips colour codes and sends `percent`, the key the HTML reads
  local host = fake_host.new()
  host.loadPlugin()
  host.gmcp("Char.Enemy", { name = "&Ra &Wstormtrooper", percent = 42 })
  local enemy = host.last("lotj-status-bar", "enemyInfo").enemy
  assert(enemy.name == "a stormtrooper" and enemy.percent == 42 and enemy.enemyPercent == nil)
  host.gmcp("Char.Enemy", {})
  enemy = host.last("lotj-status-bar", "enemyInfo").enemy
  assert(enemy.name == "" and enemy.percent == 0)
  local html = host.widgets["lotj-status-bar"].properties.content
  assert(html:find("enemy.percent", 1, true), "the HTML must read the key the handler sends")
  print("PASS: opponent name and percent reach the status bar")
end

do -- Char.Chat sets the comlink indicator
  local host = fake_host.new()
  host.loadPlugin()
  host.gmcp("Char.Chat", { commChannel = "1234", commEncrypt = true })
  local channel = host.last("lotj-status-bar", "comlink").channel
  assert(channel.name == "1234" and channel.active == true)
  host.gmcp("Char.Chat", {})
  channel = host.last("lotj-status-bar", "comlink").channel
  assert(channel.name == "" and channel.active == false)
  print("PASS: comlink state reaches the status bar")
end

do -- Ship.Info toggles the ship row; Ship.System without a table clears the location
  local host = fake_host.new()
  host.loadPlugin()
  host.gmcp("Ship.Info", { hull = 5, maxHull = 9, posX = 1, posY = 2, posZ = 3 })
  local ship = host.last("lotj-status-bar", "shipVisible")
  assert(ship.visible == true and ship.ship.hull == 5 and ship.ship.posZ == 3)
  host.gmcp("Ship.Info", {})
  assert(host.last("lotj-status-bar", "shipVisible").visible == false)
  host.gmcp("Ship.System", { x = 1, y = 2 })
  host.gmcp("Ship.System", "not a table")
  assert(#host.sends == 0)
  print("PASS: ship packets update the status bar and tolerate bad payloads")
end

do -- when timers are unavailable, a scheduled readout callback runs at once
  local host = fake_host.new({ timersFail = true })
  host.loadPlugin()
  host.post("lotj-scrapper-cockpit", "ready", {})
  host.post("lotj-scrapper-cockpit", "radar", {})
  assert(host.sends[1] == "radar")
  local position = host.last("lotj-scrapper-cockpit", "position")
  assert(position.scanState == "timeout", "without timers the readout times out immediately")
  print("PASS: scheduling falls back to an immediate callback without timers")
end

do -- lifecycle hooks are safe for the wrong session and when disconnected
  local host = fake_host.new()
  local env = host.loadPlugin()
  env.onConnect("other")
  env.onConnect(host.session.id)
  assert(host.line("Your Coordinates: 1 2 3", "other") == nil, "lines from other sessions are ignored")
  host.session.connected = false
  assert(host.line("(OOC) Pilot: hi") == nil)
  env.onDisconnect(host.session.id)
  assert(env.onCommand("s1", "x") == nil and env.onSend("s1", "x") == nil)
  assert(env.onSaveState("s1") == nil and env.cleanup() == nil)
  assert(#host.sends == 0)
  print("PASS: lifecycle hooks are passive outside the active session")
end

do -- scaffolding handlers for widgets that do not exist yet do nothing
  local host = fake_host.new()
  local env = host.loadPlugin()
  for _, name in ipairs({ "handleCombatHUDClick", "handleShipHUDClick", "handleDatapadClick",
                          "handleRadarClick", "loadSavedState" }) do
    assert(env[name]({}) == nil, name .. " must be a no-op")
  end
  assert(#host.sends == 0)
  print("PASS: placeholder handlers are no-ops")
end
