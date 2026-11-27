-- Offline integration through the real entry point with a stubbed MudForge host.
local function noop() end
local cockpit_id = "lotj-scrapper-cockpit"
local widgets, commands, gmcp = {}, {}, {}
local widget_events, messages, sends = {}, {}, {}
local comms_handler, chat_messages = nil, {}
local opens, focus_calls = 0, 0
local local_widgets, timers = {}, {}
local status_ship_visible
local fitted_panel, map_ready, room_changed
local connected, session_id = true, "first"
local env = setmetatable({
  getWindowSize = function() return { width = 1280, height = 800 } end,
  getSession = function() return { id = session_id, connected = connected } end,
  createWidget = function(config)
    widgets[config.name] = config
    return config.name
  end,
  setActiveWidget = noop,
  registerTheme = noop,
  onMapReady = function(callback) map_ready = callback end,
  onRoomChange = function(callback) room_changed = callback end,
  onMapRoomClick = noop,
  addTrigger = noop,
  on = noop,
  print = noop,
  onGMCPUpdate = function(event, callback)
    assert(not gmcp[event], "duplicate GMCP handler: " .. event)
    gmcp[event] = callback
  end,
  registerWidgetEvent = function(id, event, callback)
    if id == "lotj-comms-hub" and event == "luamsg" then
      assert(not comms_handler, "duplicate comms handler")
      comms_handler = callback
    end
    if id ~= cockpit_id then return end
    assert(not widget_events[event], "duplicate cockpit event handler")
    widget_events[event] = callback
  end,
  registerCommand = function(command, callback)
    assert(not commands[command], "duplicate cockpit command")
    commands[command] = callback
  end,
  showWidget = function(id, force)
    assert(force == true, "an explicit open must reopen a closed widget")
    if id == cockpit_id then opens = opens + 1
    else local_widgets[#local_widgets + 1] = id end
  end,
  setWidgetProperty = function(id, property, value)
    if id ~= cockpit_id then return end
    assert(property == "content" and widget_events.luamsg,
      "register the cockpit handler before loading the document")
    assert(value:find('mudforge.send("ready"', 1, true), "missing cockpit readiness message")
  end,
  sendWidgetMessage = function(id, value)
    if id == cockpit_id then messages[#messages + 1] = value end
    if id == "lotj-comms-hub" then chat_messages[#chat_messages + 1] = value end
    if id == "lotj-status-bar" and value.event == "shipVisible" then
      status_ship_visible = value.visible
    end
  end,
  resizeWidget = function(id, width, height)
    assert(id == cockpit_id and width == 650 and height == 635)
    fitted_panel = true
  end,
  getCurrentRoom = function() return { name = "Main Thoroughfare", zone = "Ring of Kafrene" } end,
  addTimer = function(interval, callback)
    timers[#timers + 1] = { interval = interval, callback = callback }
    return tostring(#timers)
  end,
  removeTimer = function(id) timers[tonumber(id)].cancelled = true end,
  send = function(command) sends[#sends + 1] = command end,
  focusPrompt = function() focus_calls = focus_calls + 1 end,
}, { __index = _G })

local load_env = dofile("tests/support/load_env.lua")
local function load_in_host(path)
  return load_env(path, env)()
end

env.loadModule = load_in_host
load_in_host("src/lotj.lua")
env.init()
map_ready()
assert(widgets[cockpit_id].type == "html" and widgets[cockpit_id].visible == false)
assert(#sends == 0 and opens == 0, "init must be passive")
assert(commands["lotj-cockpit"], "missing /lotj-cockpit command")("")
assert(commands["lotj-nav"], "missing /lotj-nav command")("")
assert(opens == 2 and #sends == 0, "opening either alias must not send anything")

local chat = "(OOC) Pilot: Checking in"
assert(env.onLine("first", "\27[32m" .. chat .. "\27[0m", chat) == nil, "chat must leave the terminal line alone")
env.onLine("other", chat, chat)
env.onLine("first", "Your Coordinates: 0 0 0", "Your Coordinates: 0 0 0")
assert(#chat_messages == 0)
comms_handler({ event = "ready" })
assert(#chat_messages == 1 and chat_messages[1].event == "chatMessage")
assert(chat_messages[1].msg.channel == "ooc" and chat_messages[1].msg.text == "Checking in")
assert(#sends == 0 and focus_calls == 0, "received chat must leave the game and prompt unchanged")

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
assert(#messages[1].systems == 15 and messages[1].event == "galaxy", "the catalogue must be available offline")
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
connected = false
env.onDisconnect("first")
assert(latest().position == nil, "the position must clear on disconnect")
local published = #messages
ship_info({ posX = 99, posY = 99, posZ = 99 })
assert(#messages == published, "a packet delivered after disconnect must not repopulate the cockpit")
post("read-room", {})
assert(latest().event == "room" and latest().name == "Main Thoroughfare" and latest().zone == "Ring of Kafrene")
room_changed(465, 464, { name = "Charlie Block", area = "Ring of Kafrene" })
assert(latest().event == "room" and latest().name == "Charlie Block" and latest().zone == "Ring of Kafrene",
  "moving between rooms must update the displayed room without opening the tab again")
post("open-map", {})
post("open-comms", {})
post("fit-panel", {})
assert(fitted_panel)
assert(local_widgets[1] == "lotj-ground-map" and local_widgets[2] == "lotj-comms-hub")
post("hover", {})
post("selection", { xyz = "12 -34 0" })
assert(#sends == 0 and focus_calls == 0, "passive input must never send or focus")

post("radar", {})
assert(#sends == 0 and latest().event == "disconnected" and focus_calls == 0)
connected, session_id = true, "second"
env.onConnect("second")
assert(latest().event == "position" and latest().connected, "connection must dismiss the scan notice")
ship_info({ posX = 20, posY = 0, posZ = 0 })
env.onDisconnect("first")
assert(latest().position.x == 20, "a late disconnect must not clear the current position")
post("radar", { command = "launch" })
post("proximity", {})
assert(#sends == 2 and sends[1] == "radar" and sends[2] == "proximity" and focus_calls == 2,
  "each click must request exactly one documented scan")
print("PASS: cockpit loads, renders ship position, and sends only explicitly requested scans")

local function line(text, from)
  env.onLine(from or "second", "\27[32m" .. text .. "\27[0m", text)
end

local function fireTimer(interval)
  for i = #timers, 1, -1 do
    local timer = timers[i]
    if timer.interval == interval and not timer.cancelled then
      timer.cancelled = true
      timer.callback()
      return
    end
  end
  error("missing timer " .. interval)
end

line("Initial Object 1 2 3")
line("Your Coordinates: 10 20 30")
fireTimer(250)
assert(latest().scanState == "complete" and #latest().contacts == 1)
assert(latest().contacts[1].name == "Initial Object")
local first_timeout = timers[1]
assert(first_timeout.cancelled, "completed reads must cancel their timeout")
post("radar", {})
local pending_timers = #timers
post("radar", {})
assert(#sends == 3 and #timers == pending_timers and latest().scanState == "scanning",
  "a second click during the same readout must not send or start a timer")
first_timeout.callback()
assert(latest().scanState == "scanning", "an old timer cannot end a new scan")
line("Ghost 1 2 3", "first")
line("[Chat] Message 1 2 3")
line("Your Coordinates: -30.25 0 +.5")
local early_quiet = timers[#timers]
line("(STAR) Primary -15 100 -42")
line("Abandoned Freighter 'Junker24' 40.5 -75 +130")
line("Docking Moon 110 0 -37")
assert(early_quiet.cancelled and latest().scanState == "scanning",
  "an early origin must not complete the readout before subsequent contacts")
early_quiet.callback()
assert(latest().scanState == "scanning", "a retired quiet timer must not finish the current readout")
fireTimer(250)
local radar = latest()
assert(radar.scanState == "complete" and #radar.contacts == 3)
assert(radar.position.x == -30.25 and radar.position.z == 0.5)
assert(radar.contacts[1].category == "star" and radar.contacts[1].z == -42)
assert(radar.contacts[2].name == "Junker24" and radar.contacts[2].category == "ship"
  and radar.contacts[2].x == 40.5 and radar.contacts[2].z == 130)
assert(radar.contacts[3].category == "planet")
line("Unexpected Moon 7 8 9")
line("Your Coordinates: 8 8 8")
assert(latest() == radar, "passive readouts must not replace the requested snapshot")

post("radar", {})
line("You must be in the cockpit or turret of a ship to do that!")
assert(latest().scanState == "rejected", "the LotJ cockpit refusal should complete the request")
post("proximity", {})
assert(latest().scanState == "proximity" and sends[#sends] == "proximity",
  "a proximity request must clear the previous radar error")

post("radar", {})
line("Incomplete Object 10 20 30")
fireTimer(8000)
assert(latest().scanState == "timeout" and latest().radarBusy and #latest().contacts == 3,
  "a partial readout must time out, preserve the last scan, and drain late lines")
local timedout_sends = #sends
post("radar", {})
assert(#sends == timedout_sends, "a new scan must wait while late lines are being discarded")
line("Late Object 10 20 30")
line("Your Coordinates: 8 8 8")
fireTimer(2500)
assert(not latest().radarBusy and #latest().contacts == 3 and latest().position.x == -30.25)

local galaxy_location = assert(gmcp["Ship.System"])
galaxy_location({ x = 0, y = 0 })
assert(latest().event == "galaxy" and latest().location.x == 0)
galaxy_location({ x = 26, y = 41 })
local after_jump = #messages
assert(messages[after_jump-1].position == nil and #messages[after_jump-1].contacts == 0,
  "changing systems must discard old ship coordinates and contacts")
ship_info({ posX = -30.25, posY = 0, posZ = 0.5 })
assert(#messages == after_jump, "unidentified Ship.Info cannot restore an old system's coordinates")
post("radar", {})
for i = 1, 257 do line("Catalogue Object " .. i .. " 20 30") end
line("Your Coordinates: 9 8 7")
fireTimer(250)
assert(latest().position.x == 9 and latest().scanState == "truncated" and #latest().contacts == 256)
ship_info({ posX = 10, posY = 0, posZ = 0 })
assert(latest().position.x == 10, "the scan establishes the new origin and resumes live movement")
print("PASS: radar reads formatted rows, handles out-of-order coordinates and reports truncated or late readouts")
