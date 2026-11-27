-- Offline integration through the real entry point with a stubbed MudForge host.
local function noop() end
local cockpit_id = "lotj-scrapper-cockpit"
local widgets, commands, gmcp = {}, {}, {}
local widget_events, messages, sends = {}, {}, {}
local opens, focus_calls = 0, 0
local status_ship_visible
local connected = false
local env = setmetatable({
  getWindowSize = function() return { width = 1280, height = 800 } end,
  getSession = function() return { connected = connected } end,
  createWidget = function(config)
    widgets[config.name] = config
    return config.name
  end,
  setActiveWidget = noop,
  registerTheme = noop,
  onMapReady = noop,
  addTrigger = noop,
  on = noop,
  print = noop,
  onGMCPUpdate = function(event, callback)
    assert(not gmcp[event], "duplicate GMCP handler: " .. event)
    gmcp[event] = callback
  end,
  registerWidgetEvent = function(id, event, callback)
    if id ~= cockpit_id then return end
    assert(not widget_events[event], "duplicate cockpit event handler")
    widget_events[event] = callback
  end,
  registerCommand = function(command, callback)
    assert(not commands[command], "duplicate cockpit command")
    commands[command] = callback
  end,
  showWidget = function(id, force)
    assert(id == cockpit_id and force == true, "explicit open must reopen a closed cockpit")
    opens = opens + 1
  end,
  setWidgetProperty = function(id, property, value)
    if id ~= cockpit_id then return end
    assert(property == "content" and widget_events.luamsg,
      "register the cockpit handler before loading the document")
    assert(value:find('mudforge.send("ready"', 1, true), "missing cockpit readiness message")
  end,
  sendWidgetMessage = function(id, value)
    if id == cockpit_id then messages[#messages + 1] = value end
    if id == "lotj-status-bar" and value.event == "shipVisible" then
      status_ship_visible = value.visible
    end
  end,
  send = function(command) sends[#sends + 1] = command end,
  focusPrompt = function() focus_calls = focus_calls + 1 end,
}, { __index = _G })

local function load_in_host(path)
  if _VERSION == "Lua 5.1" then
    return setfenv(assert(loadfile(path)), env)()
  end
  return assert(loadfile(path, "t", env))()
end

env.loadModule = load_in_host
load_in_host("src/lotj.lua")
env.init()
assert(widgets[cockpit_id].type == "html" and widgets[cockpit_id].visible == false)
assert(#sends == 0 and opens == 0, "init must be passive")
assert(commands["lotj-cockpit"], "missing /lotj-cockpit command")("")
assert(opens == 1 and #sends == 0, "opening must not send anything")

local function post(event, data)
  widget_events.luamsg({ event = event, data = data })
end

local function latest()
  return messages[#messages]
end

local ship_info = assert(gmcp["Ship.Info"])
ship_info({ posX = 12, posY = -34.5, posZ = 0 })
assert(status_ship_visible == true, "the same packet must still update the status bar")
assert(#messages == 0, "the iframe must register its receiver before a publish")
post("ready", {})
local position = latest().position
assert(latest().event == "position" and position.x == 12 and position.y == -34.5 and position.z == 0,
  "ready must render the latest complete ship position")

for _, packet in ipairs({
  {}, { posX = 12 }, { posX = "12", posY = 0, posZ = 0 },
  { posX = math.huge, posY = 0, posZ = 0 }, { posX = 0 / 0, posY = 0, posZ = 0 },
}) do
  ship_info(packet)
  assert(latest().event == "position" and latest().position == nil,
    "an invalid or incomplete observation must clear the displayed position")
end
ship_info(nil)
assert(status_ship_visible == false and latest().position == nil)
ship_info({ posX = 0, posY = 0, posZ = 0 })
assert(latest().position.x == 0, "zero is a valid coordinate")
env.onDisconnect("test")
assert(latest().position == nil, "the position must clear on disconnect")
post("hover", {})
post("selection", { xyz = "12 -34 0" })
assert(#sends == 0 and focus_calls == 0, "passive input must never send or focus")

post("radar", {})
assert(#sends == 0 and latest().event == "disconnected" and focus_calls == 0)
connected = true
env.onConnect("test")
post("radar", { command = "launch" })
post("proximity", {})
assert(#sends == 2 and sends[1] == "radar" and sends[2] == "proximity" and focus_calls == 2,
  "each click must request exactly one documented scan")
print("PASS: cockpit loads, renders ship position, and sends only explicitly requested scans")
