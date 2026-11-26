-- Offline integration: the entrypoint and cockpit run against a stubbed host.
-- All positions below are synthetic manual input, never a LOTJ wire fixture.
local function noop() end
local cockpit_id = "lotj-scrapper-cockpit"
local widgets, commands, events = {}, {}, {}
local sends, drafts, opened = {}, {}, {}
local content, message
local now = 100
local env = setmetatable({
  getWindowSize = function() return { width = 1280, height = 800 } end,
  createWidget = function(config)
    widgets[config.name] = config
    return config.name
  end,
  setActiveWidget = noop,
  registerTheme = noop,
  onGMCPUpdate = noop,
  registerWidgetEvent = function(id, event, callback)
    if id ~= cockpit_id then return end
    assert(not events[event], "duplicate cockpit event handler")
    events[event] = callback
  end,
  registerCommand = function(name, callback) commands[name] = callback end,
  showWidget = function(id, force)
    assert(id == cockpit_id and force == true, "explicit open must reopen even after close")
    opened[#opened + 1] = id
  end,
  setWidgetProperty = function(id, property, value)
    assert(id == cockpit_id and property == "content")
    assert(events.luamsg, "register the message handler before loading markup")
    content = value
  end,
  sendWidgetMessage = function(id, value)
    assert(id == cockpit_id)
    message = value
  end,
  send = function(command) sends[#sends + 1] = command end,
  focusPrompt = function(draft) drafts[#drafts + 1] = draft or false end,
  os = { clock = function() return now end },
}, { __index = _G })

local function load_in_host(path)
  if _VERSION == "Lua 5.1" then
    return setfenv(assert(loadfile(path)), env)()
  end
  return assert(loadfile(path, "t", env))()
end

env.loadModule = function(path)
  -- Existing modules have their own regression tests; isolate the new widget.
  if path == "src/widgets/lotj-scrapper-cockpit.lua" then return load_in_host(path) end
end

load_in_host("src/lotj.lua")
env.init()
local open = assert(commands["lotj-cockpit"], "missing /lotj-cockpit command")
assert(widgets[cockpit_id].type == "html" and widgets[cockpit_id].visible == false)
assert(content:find("mudforge.send", 1, true), "cockpit missing its HTML bridge")
assert(#sends == 0 and #opened == 0, "init must be passive")
open("")
assert(#opened == 1 and #sends == 0, "opening must not send anything")

local function post(event, data)
  events.luamsg({ event = event, data = data })
end

post("ready", {})
assert(#drafts == 0, "ready must not steal prompt focus")
post("hover", {})
post("selection", { xyz = "12 -34 0" })
assert(#sends == 0 and #drafts == 0, "hover and selection must be passive")
post("radar", {})
assert(#sends == 1 and sends[1] == "radar" and drafts[1] == false)
post("proximity", { distance = "" })
post("proximity", { distance = " 2500 " })
assert(#sends == 3 and sends[2] == "proximity" and sends[3] == "proximity 2500")
print("PASS: cockpit opens explicitly and only sends manually requested scans")
