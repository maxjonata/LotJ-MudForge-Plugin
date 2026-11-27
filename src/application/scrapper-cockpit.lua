local READOUT_TIMEOUT_MS = 8000
local READOUT_QUIET_MS = 250
local LATE_LINE_QUIET_MS = 2500
local MAX_CONTACTS = 256

-- A requested readout is published only after an origin and a quiet window.
-- LotJ's terminal lines carry no request identifier.
local function new(ports)
  local position, system, scanState = nil, nil, "idle"
  local pending, draining = nil, nil
  local awaitingOrigin = false
  local contacts = {}

  local function refresh()
    ports.publish(position, contacts, scanState, pending ~= nil or draining ~= nil)
  end

  local function cancelPending()
    local request = pending
    if not request then return end
    pending = nil
    if request.cancelTimeout then request.cancelTimeout() end
    if request.quiet and request.quiet.cancel then request.quiet.cancel() end
  end

  local function cancelDrain()
    local previous = draining
    draining = nil
    if previous and previous.cancel then previous.cancel() end
  end

  local function drainLateLines()
    cancelDrain()
    local drain = {}
    draining = drain
    drain.cancel = ports.schedule(LATE_LINE_QUIET_MS, function()
      if draining ~= drain then return end
      draining = nil
      refresh()
    end)
  end

  local function resetSession()
    cancelPending()
    cancelDrain()
    position, system, scanState = nil, nil, "idle"
    contacts = {}
    awaitingOrigin = false
    ports.publishSystem(nil)
    refresh()
  end

  local function observeSystem(x, y)
    local nextSystem = ports.shipPosition.observe(x, y, 0)
    if system and (not nextSystem or system.x ~= nextSystem.x or system.y ~= nextSystem.y) then
      local inFlight = pending ~= nil
      cancelPending()
      if inFlight then drainLateLines() end
      position = nil
      contacts = {}
      -- Ship.Info has no system identifier to distinguish a delayed old position.
      awaitingOrigin, scanState = true, "awaiting-origin"
      refresh()
    end
    system = nextSystem
    ports.publishSystem(system)
  end

  local function observe(x, y, z)
    if awaitingOrigin then return end
    local nextPosition = ports.shipPosition.observe(x, y, z)
    if nextPosition then
      position = nextPosition
      refresh()
    elseif position then
      position, contacts = nil, {}
      if not pending then scanState = "idle" end
      refresh()
    end
  end

  local function complete(request)
    if pending ~= request then return end
    position, contacts = request.origin, request.contacts
    awaitingOrigin = false
    scanState = request.truncated and "truncated" or "complete"
    cancelPending()
    refresh()
  end

  local function requestScan(kind)
    if kind == "proximity" then
      if not ports.scan(kind) then return false end
      if not pending then
        scanState = awaitingOrigin and "awaiting-origin" or "proximity"
        refresh()
      end
      return true
    end
    if kind ~= "radar" then return false end
    if pending or draining then return true end
    local request = { contacts = {} }
    pending, scanState = request, "scanning"
    if not ports.scan(kind) then
      cancelPending()
      scanState = "idle"
      refresh()
      return false
    end
    refresh()
    if pending == request then
      request.cancelTimeout = ports.schedule(READOUT_TIMEOUT_MS, function()
        if pending ~= request then return end
        request.cancelTimeout = nil
        if request.origin then
          complete(request)
          return
        end
        cancelPending()
        scanState = "timeout"
        drainLateLines()
        refresh()
      end)
    end
    return true
  end

  local function readLine(line)
    if not pending and not draining then return end
    local reading = ports.radarScan.read(line)
    if not reading then return end
    if draining then
      drainLateLines()
      return
    end

    local request = pending
    if reading.kind == "rejected" then
      cancelPending()
      scanState = "rejected"
      refresh()
      return
    end
    if reading.kind == "origin" then
      request.origin = ports.shipPosition.observe(reading.x, reading.y, reading.z)
    elseif #request.contacts < MAX_CONTACTS then
      request.contacts[#request.contacts + 1] = reading
    else
      request.truncated = true
    end
    if request.origin then
      -- The community parser treats the origin as a footer. Allow nearby rows
      -- on either side so a readout with its origin first is accepted as well.
      if request.quiet and request.quiet.cancel then request.quiet.cancel() end
      local quiet = {}
      request.quiet = quiet
      quiet.cancel = ports.schedule(READOUT_QUIET_MS, function()
        if pending ~= request or request.quiet ~= quiet then return end
        request.quiet = nil
        complete(request)
      end)
    end
  end

  return {
    observe = observe, observeSystem = observeSystem, refresh = refresh,
    requestScan = requestScan, readLine = readLine, resetSession = resetSession,
  }
end

return { new = new }
