-- Edge paths of widget adapters and the cockpit use case through the fake host.
local fake_host = dofile("tests/support/fake_host.lua")

do -- placeholder widgets: clicks run their (empty) handler and return focus
  local host = fake_host.new()
  host.loadPlugin()
  for _, id in ipairs({ "lotj-ship-hud", "lotj-datapad", "lotj-space-radar" }) do
    local focus = host.count("focusPrompt")
    assert(host.events[id] and host.events[id].click, "missing click handler for " .. id)
    host.events[id].click({})
    assert(host.count("focusPrompt") == focus + 1, id .. " click must return focus to the prompt")
  end
  assert(#host.sends == 0)
  print("PASS: placeholder widget clicks only return focus")
end

do -- the cockpit answers read-galaxy even before ready
  local host = fake_host.new()
  host.loadPlugin()
  host.post("lotj-scrapper-cockpit", "read-galaxy", {})
  local galaxy = host.last("lotj-scrapper-cockpit", "galaxy")
  assert(galaxy and #galaxy.systems > 0, "read-galaxy marks the panel ready and sends the catalogue")
  print("PASS: read-galaxy publishes the public catalogue")
end

do -- radar timeout after the origin arrived completes the readout instead of failing
  local host = fake_host.new()
  host.loadPlugin()
  host.post("lotj-scrapper-cockpit", "ready", {})
  host.post("lotj-scrapper-cockpit", "radar", {})
  host.line("Your Coordinates: 1 2 3")
  host.fireTimers(8000) -- timeout fires before the 250 ms quiet window
  local position = host.last("lotj-scrapper-cockpit", "position")
  assert(position.scanState == "complete" and position.position.x == 1)
  print("PASS: a timeout after the origin completes the scan")
end

do -- comms hub helpers are inert before init and forward after it
  local host = fake_host.new()
  local comms = host.env.loadModule("src/widgets/lotj-comms-hub.lua")
  host.env.handleCombatStats({ hits = 1 })
  host.env.handleAutopilotRoute({ "a" })
  host.env.handleUnreadBadge("ooc", 2)
  assert(next(host.messages) == nil, "nothing is sent before the hub exists")
  host.env.createWidget({ name = "hub" })
  comms.init("hub")
  host.env.handleCombatStats({ hits = 1 })
  host.env.handleAutopilotRoute({ "a" })
  host.env.handleUnreadBadge("ooc", 2)
  local events = {}
  for _, message in ipairs(host.messages.hub) do events[#events + 1] = message.event end
  assert(table.concat(events, ",") == "combatStats,autopilotRoute,unreadBadge")
  print("PASS: comms hub helpers wait for init")
end

do -- ground map: widget creation failure is reported and later calls are safe
  local host = fake_host.new({ failWidget = { ["lotj-ground-map"] = true } })
  local map = host.env.loadModule("src/widgets/lotj-ground-map.lua")
  map.init(function() end)
  local reported = false
  for _, call in ipairs(host.calls) do
    if call[1] == "print" and tostring(call[2]):find("Failed to create ground map", 1, true) then reported = true end
  end
  assert(reported, "a failed widget must be reported")
  host.env.toggleGroundMap()
  map.open()
  assert(host.count("showWidget") == 0 and host.count("hideWidget") == 0)
  print("PASS: ground map tolerates a failed widget")
end

do -- ground map: toggle shows then hides; map clicks on known rooms announce a target
  local host = fake_host.new()
  local map = host.env.loadModule("src/widgets/lotj-ground-map.lua")
  map.init(function() end)
  host.mapReady()
  host.roomChange(7, nil, { name = "Hangar", amenities = { "B", "unknown" } })
  host.widgets["lotj-ground-map"].visible = false
  host.env.toggleGroundMap()
  assert(host.widgets["lotj-ground-map"].visible == true)
  host.env.toggleGroundMap()
  assert(host.widgets["lotj-ground-map"].visible == false)
  local emits = host.count("emit")
  host.env.onMapRoomClickHandler(7)
  assert(host.count("emit") == emits + 1, "a known room click emits lotj:target:set")
  host.env.onMapRoomClickHandler(999)
  assert(host.count("emit") == emits + 1, "unknown rooms emit nothing")
  print("PASS: ground map toggle and room click target")
end
