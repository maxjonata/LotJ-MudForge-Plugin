-- QA-07 DEV harness. Loaded by dev/main.lua BEFORE the production entry point,
-- it replaces the host ports the plugin talks to (send, sendGMCP, getSession,
-- timers) with recorders and wraps the widget/GMCP registration calls so
-- scenarios can drive the real code: GMCP packets, MUD lines (onLine plus the
-- real trigger engine through feedTriggers), widget messages and timers.
-- Nothing a scenario does reaches the MUD. Uses only APIs from the MudForge
-- guide; `setmetatable`/`debug` are blocked in the client, so none are used.
local real = {
  createWidget = createWidget,
  sendWidgetMessage = sendWidgetMessage,
  registerWidgetEvent = registerWidgetEvent,
  onGMCPUpdate = onGMCPUpdate,
}

local state = {
  session = { id = "lotj-dev", connected = true },
  sends = {}, timers = {}, messages = {}, events = {}, gmcp = {}, ids = {},
}

-- Ports replaced outright: scenarios own the connection and the clock.
send = function(command)
  state.sends[#state.sends + 1] = command
  return true
end
sendGMCP = function(package, payload)
  state.sends[#state.sends + 1] = "GMCP " .. tostring(package) .. " " .. tostring(payload)
  return true
end
getSession = function() return state.session end
addTimer = function(interval, callback)
  state.timers[#state.timers + 1] = { interval = interval, callback = callback }
  return "dev-" .. #state.timers
end
removeTimer = function(id)
  local timer = state.timers[tonumber(tostring(id):match("^dev%-(%d+)$") or "")]
  if timer then timer.cancelled = true end
end

-- Registration calls are recorded, then forwarded so the real client still
-- renders widgets and keeps its own bookkeeping.
createWidget = function(config)
  local id = real.createWidget(config)
  if id and type(config) == "table" and config.name then state.ids[config.name] = id end
  return id
end
sendWidgetMessage = function(id, message)
  local key = id == nil and "<nil>" or id
  state.messages[key] = state.messages[key] or {}
  table.insert(state.messages[key], message)
  return real.sendWidgetMessage(id, message)
end
registerWidgetEvent = function(id, event, callback)
  local key = id == nil and "<nil>" or id
  state.events[key] = state.events[key] or {}
  state.events[key][event] = callback
  return real.registerWidgetEvent(id, event, callback)
end
onGMCPUpdate = function(package, callback)
  state.gmcp[package] = callback
  return real.onGMCPUpdate(package, callback)
end

local function oneLine(text)
  return (tostring(text):gsub("%s*\n%s*", " | "))
end

local function context(settle)
  local t = { session = state.session, waiting = 0 }

  function t.check(condition, message)
    if not condition then error(message or "check failed", 0) end
  end
  function t.eq(actual, expected, label)
    if actual ~= expected then
      error(("%s: expected %s, got %s"):format(label or "value", tostring(expected), tostring(actual)), 0)
    end
  end
  function t.send(command) return send(command) end
  function t.sends() return state.sends end
  function t.lastSend() return state.sends[#state.sends] end
  function t.gmcp(package, data)
    local handler = state.gmcp[package]
    t.check(handler, "no GMCP handler for " .. package)
    handler(data)
  end
  function t.line(text)
    if onLine then onLine(state.session.id, text, text) end
  end
  -- Runs lines through the plugin's own triggers. feedTriggers runs them after
  -- the current code finishes, so the scenario continues in `after`.
  function t.feed(lines, after)
    t.check(feedTriggers, "feedTriggers is not available")
    t.waiting = t.waiting + 1
    feedTriggers(lines, function()
      t.waiting = t.waiting - 1
      local ok, err = pcall(after or function() end, t)
      if not ok then return settle(false, err) end
      if t.waiting == 0 then settle(true) end
    end)
  end
  function t.post(name, event, data)
    local id = state.ids[name] or name
    local handler = state.events[id] and state.events[id].luamsg
    t.check(handler, "no luamsg handler for widget " .. name)
    handler({ event = event, data = data or {} })
  end
  function t.last(name, event)
    local list = state.messages[state.ids[name] or name] or {}
    for i = #list, 1, -1 do
      if event == nil or list[i].event == event then return list[i] end
    end
  end
  function t.fireTimers(interval)
    for i = 1, #state.timers do
      local timer = state.timers[i]
      if not timer.cancelled and (interval == nil or timer.interval == interval) then
        timer.cancelled = true
        timer.callback()
      end
    end
  end
  function t.disconnect()
    state.session.connected = false
    if onDisconnect then onDisconnect(state.session.id) end
  end
  return t
end

-- Fresh recordings and a reconnected session before every scenario; the
-- production onConnect hook resets the cockpit, target and comms history.
local function reset()
  state.sends, state.timers, state.messages = {}, {}, {}
  state.session.connected = true
  if onConnect then onConnect(state.session.id) end
  state.sends = {}
end

LotjDev = { state = state }

-- Runs scenarios in order and prints one machine-readable line each, then
-- `LOTJDEV SUMMARY passed=N failed=M`. Returns the results table; when a
-- scenario waits on feedTriggers the summary arrives later (onFinish).
function LotjDev.run(list, filter, onFinish)
  local results = { passed = 0, failed = 0, failures = {} }
  local index = 0
  local nextScenario

  local function finish()
    results.summary = ("LOTJDEV SUMMARY passed=%d failed=%d"):format(results.passed, results.failed)
    print(results.summary)
    if onFinish then onFinish(results) end
  end

  nextScenario = function()
    index = index + 1
    local scenario = list[index]
    if not scenario then return finish() end
    if filter and filter ~= "" and not scenario.name:find(filter, 1, true) then return nextScenario() end
    local settled = false
    local function settle(ok, err)
      if settled then return end
      settled = true
      if ok then
        results.passed = results.passed + 1
        print("LOTJDEV PASS " .. scenario.name)
      else
        results.failed = results.failed + 1
        results.failures[#results.failures + 1] = scenario.name
        print("LOTJDEV FAIL " .. scenario.name .. ": " .. oneLine(err))
      end
      nextScenario()
    end
    local ok, err = pcall(reset)
    if not ok then return settle(false, "reset failed: " .. tostring(err)) end
    local t = context(settle)
    ok, err = pcall(scenario.run, t)
    if not ok then return settle(false, err) end
    if t.waiting == 0 then settle(true) end
  end

  nextScenario()
  return results
end

function LotjDev.scenarios()
  local list = {}
  for _, path in ipairs(loadModule("dev/scenarios/index.lua")) do
    list[#list + 1] = loadModule(path)
  end
  return list
end

return LotjDev
