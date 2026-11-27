-- NAV-08 use cases. Radar updates and selection are passive; only aim, face
-- and fire send, once per call. Ports: targetLock (domain), send(cmd) -> bool,
-- publish(snapshot).
local function same(a, b)
  for key, value in pairs(a) do if b[key] ~= value then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

local function new(ports)
  local lock = ports.targetLock
  local state, published = lock.empty(), nil
  local origin, contacts = nil, nil

  local function refresh()
    published = state
    ports.publish(state)
  end

  local function update(nextState)
    state = nextState
    if not published or not same(published, state) then refresh() end
  end

  local function onRadar(nextOrigin, nextContacts)
    origin, contacts = nextOrigin, nextContacts
    update(lock.onRadar(state, origin, contacts))
  end

  local function select(name)
    local nextState = lock.select(state, origin, contacts, name)
    if nextState == state then return false end
    update(nextState)
    return true
  end

  local function act(action, weapon)
    local command = lock.command(action, state, weapon)
    if not command then return false end
    if action == "fire" and state.status ~= "sent" then return false end
    if not ports.send(command) then return false end
    if action == "target" then update(lock.markSent(state)) end
    return true
  end

  local function clear()
    update(lock.empty())
  end

  local function reset()
    origin, contacts = nil, nil
    clear()
  end

  return {
    onRadar = onRadar, select = select, clear = clear, reset = reset, refresh = refresh,
    aim = function() return act("target") end,
    face = function() return act("face") end,
    fire = function(weapon) return act("fire", weapon) end,
  }
end

return { new = new }
