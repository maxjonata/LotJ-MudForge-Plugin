-- The view receives position, contacts and the outcome of the current scan.
-- After a radar click, only a completed LotJ readout replaces the contacts.
local function new(ports)
  local position, pending, scanState = nil, nil, "idle"
  local contacts = {}

  local function refresh()
    ports.publish(position, contacts, scanState)
  end

  local function reset()
    position, pending, scanState = nil, nil, "idle"
    contacts = {}
    refresh()
  end

  local function observe(x, y, z)
    local nextPosition = ports.shipPosition.observe(x, y, z)
    if not nextPosition then
      if position then reset() end
      return
    end
    position = nextPosition
    refresh()
  end

  local function requestScan(kind)
    if kind ~= "radar" then return ports.scan(kind) end
    if pending then return true end
    local scan = {}
    pending, scanState = scan, "scanning"
    if not ports.scan(kind) then
      pending, scanState = nil, "idle"
      refresh()
      return false
    end
    refresh()
    if pending == scan then
      ports.afterReadout(function()
        if pending ~= scan then return end
        pending, scanState = nil, "timeout"
        refresh()
      end)
    end
    return true
  end

  local function readLine(line)
    if not pending then return end
    local reading = ports.radarScan.read(line)
    if not reading then return end
    if reading.kind == "contact" then
      if #pending < 256 then pending[#pending + 1] = reading end
    elseif reading.kind == "origin" then
      position = ports.shipPosition.observe(reading.x, reading.y, reading.z)
      contacts, pending, scanState = pending, nil, "complete"
      refresh()
    else
      pending, scanState = nil, "rejected"
      refresh()
    end
  end

  return { observe = observe, refresh = refresh, requestScan = requestScan, readLine = readLine, reset = reset }
end

return { new = new }
