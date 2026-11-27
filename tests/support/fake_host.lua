-- Recording fake of the MudForge host APIs the plugin uses, for offline specs.
-- Every API call is appended to host.calls as { name, ... }. Unknown globals stay
-- nil, so `if someGlobal then` checks behave as in the client.
local load_env = dofile("tests/support/load_env.lua")

local function new(options)
  options = options or {}
  local host = {
    calls = {}, widgets = {}, events = {}, messages = {}, gmcpHandlers = {},
    commands = {}, triggers = {}, timers = {}, sends = {}, themes = {},
    session = { id = options.sessionId or "s1", connected = options.connected ~= false },
    window = options.window or { width = 1280, height = 800 },
    room = options.room,
  }

  local function record(name, ...)
    host.calls[#host.calls + 1] = { name, ... }
  end

  local api = {}
  local function define(name, fn)
    api[name] = function(...)
      record(name, ...)
      return fn(...)
    end
  end

  define("getWindowSize", function() return host.window end)
  define("getSession", function() return host.session end)
  define("createWidget", function(config)
    if options.failWidget and options.failWidget[config.name] then return nil end
    host.widgets[config.name] = { config = config, visible = config.visible ~= false, properties = {} }
    return config.name
  end)
  define("destroyWidget", function(id) host.widgets[id] = nil end)
  define("setActiveWidget", function() end)
  define("setWidgetProperty", function(id, property, value)
    if host.widgets[id] then host.widgets[id].properties[property] = value end
  end)
  define("getWidgetProperty", function(id, property)
    local widget = host.widgets[id]
    if not widget then return nil end
    if property == "visible" then return widget.visible end
    return widget.properties[property]
  end)
  define("showWidget", function(id) if host.widgets[id] then host.widgets[id].visible = true end end)
  define("hideWidget", function(id) if host.widgets[id] then host.widgets[id].visible = false end end)
  define("moveWidget", function() end)
  define("resizeWidget", function() end)
  define("registerWidgetEvent", function(id, event, callback)
    id = id == nil and "<nil>" or id -- the client would warn; specs can still fire it
    host.events[id] = host.events[id] or {}
    host.events[id][event] = callback
  end)
  define("sendWidgetMessage", function(id, message)
    host.messages[id] = host.messages[id] or {}
    table.insert(host.messages[id], message)
  end)
  define("focusPrompt", function() end)
  define("registerTheme", function(theme)
    host.themes[#host.themes + 1] = theme
    return options.themeId ~= false and theme.id or nil
  end)
  define("setTheme", function(id) host.activeTheme = id end)
  define("onGMCPUpdate", function(package, callback) host.gmcpHandlers[package] = callback end)
  define("registerCommand", function(name, callback) host.commands[name] = callback end)
  define("addTrigger", function(pattern, callback, regex)
    host.triggers[#host.triggers + 1] = { pattern = pattern, callback = callback, regex = regex }
    return #host.triggers
  end)
  -- Offline stand-in for the client's trigger engine: plain triggers match as
  -- substrings; regex triggers only support the `(.*?)` and `\.` the plugin
  -- uses today. Runs synchronously; the client runs the batch afterwards.
  define("feedTriggers", function(lines, onDone)
    if type(lines) == "string" then lines = { lines } end
    for _, line in ipairs(lines) do
      for _, trigger in ipairs(host.triggers) do
        if trigger.regex then
          local pattern = trigger.pattern:gsub("%(%.%*%?%)", "(.-)"):gsub("\\%.", "%%.")
          local captures = { line:match(pattern) }
          if captures[1] then trigger.callback({ line, (table.unpack or unpack)(captures) }, line, captures) end
        elseif line:find(trigger.pattern, 1, true) then
          trigger.callback({ line }, line, {})
        end
      end
    end
    if onDone then onDone(0, #lines) end
  end)
  define("on", function() end)
  define("emit", function() end)
  define("addTimer", function(interval, callback)
    if options.timersFail then return "" end
    host.timers[#host.timers + 1] = { interval = interval, callback = callback }
    return tostring(#host.timers)
  end)
  define("removeTimer", function(id)
    local timer = host.timers[tonumber(id)]
    if timer then timer.cancelled = true end
  end)
  define("send", function(command) host.sends[#host.sends + 1] = command end)
  define("getCurrentRoom", function() return host.room end)
  define("getPlayerRoom", function() return host.room and host.room.id end)
  define("setPlayerRoom", function() end)
  define("setRoomColor", function() end)
  define("setRoomSymbol", function() end)
  define("onMapReady", function(callback) host.mapReady = callback end)
  define("onRoomChange", function(callback) host.roomChange = callback end)
  define("onMapRoomClick", function(callback) host.mapRoomClick = callback end)

  local env = setmetatable({}, { __index = function(_, key)
    if api[key] then return api[key] end
    return _G[key]
  end })
  api.loadModule = function(path) return load_env(path, env)() end
  api.print = function(...) record("print", ...) end
  host.env = env

  function host.loadPlugin()
    load_env("src/lotj.lua", env)()
    if env.init then env.init() end
    return env
  end

  function host.gmcp(package, data)
    local handler = assert(host.gmcpHandlers[package], "no GMCP handler for " .. package)
    handler(data)
  end

  function host.line(text, sessionId)
    if env.onLine then return env.onLine(sessionId or host.session.id, text, text) end
  end

  function host.post(widgetId, event, data)
    local handlers = assert(host.events[widgetId], "no events for widget " .. tostring(widgetId))
    local luamsg = assert(handlers.luamsg, "no luamsg handler for " .. tostring(widgetId))
    luamsg({ event = event, data = data })
  end

  function host.last(widgetId, event)
    local list = host.messages[widgetId] or {}
    for i = #list, 1, -1 do
      if event == nil or list[i].event == event then return list[i] end
    end
  end

  function host.fireTimers(interval)
    for _, timer in ipairs(host.timers) do
      if not timer.cancelled and (interval == nil or timer.interval == interval) then
        timer.cancelled = true
        timer.callback()
      end
    end
  end

  function host.count(name)
    local n = 0
    for _, call in ipairs(host.calls) do if call[1] == name then n = n + 1 end end
    return n
  end

  return host
end

return { new = new }
