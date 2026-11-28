-- Live readout use case (UI-04): keeps the last GMCP state and publishes the
-- readouts of the station the console shows. Ports: rules (src/domain/live-readout.lua),
-- publish(message). Publishes { event = "live", station, items } only when a
-- packet touches what the focused station shows, so the page never redraws for nothing.

local function new(ports)
  local rules, publish = ports.rules, ports.publish
  local state, focused = {}, nil

  local function show()
    publish({ event = "live", station = focused, items = rules.panel(state, focused) })
  end

  local function focus(station)
    focused = type(station) == "string" and station or nil
    show()
  end

  local function observe(package, data)
    local part = rules.read(state, package, data)
    if part and focused and rules.uses(focused, part) then show() end
    return part ~= nil
  end

  -- Disconnect: nothing the game said before is current any more.
  local function reset()
    state = {}
    show()
  end

  return { focus = focus, observe = observe, reset = reset }
end

return { new = new }
