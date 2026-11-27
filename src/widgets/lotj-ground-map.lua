-- lotj-ground-map.lua
-- LOTJ Ground Map widget using MudForge type="map" and Mapper API §11.5
-- Part of the LotJ MudForge Plugin

local groundMap = nil
local mapInitialized = false
local mapGeneration = 0

-- Room cache for mapper
local roomCache = {}

-- Color palette (Okabe-Ito, WCAG AA)
local COLORS = {
  room = "#009E73",
  current = "#56B4E9",
  unknown = "#131B2E",
  corridor = "#94A3B8",
  target = "#CC79A7",
  danger = "#D55E00",
  player = "#E69F00",
}

-- Amenity symbols from upstream lotj-mudlet-ui mapper
local AMENITY_SYMBOLS = {
  B = { color = "#CC79A7", label = "Bank" },
  H = { color = "#D55E00", label = "Bacta" },
  O = { color = "#E69F00", label = "Hotel" },
  L = { color = "#94A3B8", label = "Locker/Library/Lift" },
  W = { color = "#009E73", label = "Workshop" },
  P = { color = "#56B4E9", label = "Package" },
}

--- Initialize the ground map widget
function initGroundMap()
  if groundMap then return end
  groundMap = createWidget({
    type = "map",
    name = "lotj-ground-map",
    title = "LOTJ Ground Map",
    position = { x = 20, y = 20 },
    size = { width = 400, height = 400 },
    zIndex = 18,
    visible = false,
  })

  if not groundMap then
    print("LOTJ: Failed to create ground map widget")
    return
  end

  mapGeneration = mapGeneration + 1
  local generation = mapGeneration

  -- A queued callback may run after cleanup and creation of a replacement map.
  onMapReady(function()
    if not groundMap or generation ~= mapGeneration then return end
    mapInitialized = true
    registerMapperCallbacks()
  end)

  -- MudForge uses JS regex; wildcards[1] is the first captured group.
  addTrigger([[^You enter (.*?)\.$]], function(captures, line, wildcards)
    local roomName = wildcards and wildcards[1]
    if roomName and roomName ~= "" then
      updateMapForRoom(roomName)
    end
  end, true)

  addTrigger([[^The room is (.*?)\.$]], function(captures, line, wildcards)
    local roomDesc = wildcards and wildcards[1]
    if roomDesc and roomDesc ~= "" then
      updateMapForRoom(roomDesc)
    end
  end, true)

  -- Listen for map data updates via GMCP
  onGMCPUpdate("Room.Info", function(data)
    if data and data.room then
      updateMapDisplay()
    end
  end)

  -- Handle window resize for map repositioning
  on("windowResize", function()
    if groundMap and mapInitialized and generation == mapGeneration then
      moveWidget(groundMap, 20, 20)
      resizeWidget(groundMap, 400, 400)
    end
  end)

  print("LOTJ: Ground map widget initialized")
end

--- Register Mapper API callbacks (§11.5)
function registerMapperCallbacks()
  -- Mapper API: onRoomChange(newVnum, oldVnum, room)
  onRoomChange(function(newVnum, oldVnum, room)
    if room and type(newVnum) == "number" then
      roomCache[newVnum] = room
      updateMapDisplay()
    end
  end)

  -- Mapper API: onMapRoomClick(vnum)
  onMapRoomClick(function(vnum)
    handleMapClick(vnum)
  end)
end

--- Update map for a specific room (vnum-based)
function updateMapForRoom(vnum)
  if not groundMap or not mapInitialized then return end

  -- Text captures are display labels. Only an explicit numeric ID can
  -- position the cursor, and setPlayerRoom itself fires onRoomChange.
  if type(vnum) == "number" and roomCache[vnum] and getPlayerRoom() ~= vnum then
    setPlayerRoom(vnum)
  end
  updateMapDisplay()
end

--- The native map renders rooms and tracks movement. Refresh only our symbols.
function updateMapDisplay()
  if not groundMap or not mapInitialized then return end

  -- Update room symbols for amenities (use 1-char key)
  for roomVnum, data in pairs(roomCache) do
    if data.amenities then
      for _, amenity in ipairs(data.amenities) do
        setRoomSymbol(roomVnum, amenity)
        local sym = AMENITY_SYMBOLS[amenity]
        if sym then
          setRoomColor(roomVnum, sym.color)
        end
      end
    end
  end
end

-- Accept a room-entry line from callers outside the registered text trigger.
function handleRoomEntry(line)
  local roomName = line:match("^You enter (.+)%.$")
  if roomName then updateMapForRoom(roomName) end
end

--- Handle map click events (click to target)
function handleMapClick(vnum)
  local room = roomCache[vnum]
  if room then
    emit("lotj:target:set", { room = room.name or ("Room " .. vnum), vnum = vnum })
    print("LOTJ: Target set to " .. (room.name or ("Room " .. vnum)))
  end
end

-- Handle map click from Mapper API
function onMapRoomClickHandler(vnum)
  handleMapClick(vnum)
end

local function openGroundMap()
  if groundMap then showWidget(groundMap, true) end
end

--- Toggle map visibility
function toggleGroundMap()
  if not groundMap then return end
  local visible = getWidgetProperty(groundMap, "visible")
  if visible then
    hideWidget(groundMap)
  else
    showWidget(groundMap)
    updateMapDisplay()
  end
end

--- Cleanup ground map resources
function cleanupGroundMap()
  if groundMap then
    destroyWidget(groundMap)
    groundMap = nil
  end
  mapInitialized = false
  roomCache = {}
end

return {
  init = initGroundMap,
  toggle = toggleGroundMap,
  open = openGroundMap,
  cleanup = cleanupGroundMap,
  handleMapClick = handleMapClick,
  updateMapForRoom = updateMapForRoom,
  updateMapDisplay = updateMapDisplay,
}
