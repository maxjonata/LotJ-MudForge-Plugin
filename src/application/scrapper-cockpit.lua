-- publish(position) renders a full position, or nil when one is unavailable.
-- scan(kind) requests one readout and returns whether a connection was available.
local function new(ports)
  local position = nil

  local function refresh()
    ports.publish(position)
  end

  local function observe(x, y, z)
    position = ports.shipPosition.observe(x, y, z)
    refresh()
  end

  local function requestScan(kind)
    return ports.scan(kind)
  end

  return { observe = observe, refresh = refresh, requestScan = requestScan }
end

return { new = new }
