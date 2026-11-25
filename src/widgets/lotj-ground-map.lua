-- lotj-ground-map.lua
-- LOTJ Ground Map widget using MudForge type="map" and Mapper API §11.5
-- Part of the LotJ MudForge Plugin

local groundMap = nil
local mapInitialized = false

-- Room cache for mapper
local roomCache = {}
local currentRoom = nil

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

  mapInitialized = true

  -- Register Mapper API callbacks via onMapReady
  onMapReady(function()
    registerMapperCallbacks()
  end)

  -- Set up triggers for room entry and map events
  addTrigger("^You enter (.*?)%.$", function(line)
    local roomName = line:match("^You enter (.*?)%.$")
    if roomName then
      currentRoom = roomName
      updateMapForRoom(roomName)
    end
  end, true)

  addTrigger("^The room is (.*?)%.$", function(line)
    local roomDesc = line:match("^The room is (.*?)%.$")
    if roomDesc then
      updateMapForRoom(roomDesc)
    end
  end, true)

  -- Listen for map data updates via GMCP
  onGMCPUpdate("Room.Info", function(data)
    if data and data.room then
      currentRoom = data.room.name or currentRoom
      updateMapForRoom(currentRoom)
    end
  end)

  -- Handle window resize for map redraw
  on("windowResize", function()
    if groundMap and mapInitialized then
      redrawMap()
    end
  end)

  print("LOTJ: Ground map widget initialized")
end

--- Register Mapper API callbacks (§11.5)
function registerMapperCallbacks()
  -- Mapper API: onRoomChange(newVnum, oldVnum, room)
  onRoomChange(function(newVnum, oldVnum, room)
    if room then
      roomCache[newVnum] = room
      currentRoom = room.name or currentRoom
      updateMapDisplay()
    end
  end)

  -- Mapper API: onMapRoomClick(vnum)
  onMapRoomClick(function(vnum)
    handleMapClick(vnum)
  end)
end

--- Update map for a specific room
function updateMapForRoom(roomName)
  if not groundMap or not mapInitialized then return end

  -- The type="map" widget renders the map database automatically.
  -- We populate rooms via the Mapper API and set the player's current room.
  if currentRoom then
    local room = roomCache[currentRoom]
    if room then
      addMapRoom(currentRoom, {
        name = room.name or currentRoom,
        area = room.area or "Unknown",
        x = room.x or 0,
        y = room.y or 0,
        z = room.z or 0,
      })
      setPlayerRoom(currentRoom)
    end
  end

  -- Update room symbols for amenities
  for vnum, data in pairs(roomCache) do
    if data.amenities then
      for _, amenity in ipairs(data.amenities) do
        local sym = AMENITY_SYMBOLS[amenity]
        if sym then
          setRoomSymbol(vnum, sym.label)
          setRoomColor(vnum, sym.color)
        end
      end
    end
  end
end

--- Update map display from room cache
function updateMapDisplay()
  if not groundMap or not mapInitialized then return end

  for vnum, data in pairs(roomCache) do
    addMapRoom(vnum, {
      name = data.name or ("Room " .. vnum),
      area = data.area or "Unknown",
      x = data.x or 0,
      y = data.y or 0,
      z = data.z or 0,
    })
  end

  if currentRoom then
    setPlayerRoom(currentRoom)
  end
end

--- Handle map click events (click to target)
function handleMapClick(vnum)
  local room = roomCache[vnum]
  if room then
    emit("lotj:target:set", { room = room.name or ("Room " .. vnum), vnum = vnum })
    print("LOTJ: Target set to " .. (room.name or ("Room " .. vnum)))
  end
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
  currentRoom = nil
end

return {
  init = initGroundMap,
  toggle = toggleGroundMap,
  cleanup = cleanupGroundMap,
  handleMapClick = handleMapClick,
  updateMapForRoom = updateMapForRoom,
  updateMapDisplay = updateMapDisplay,
}
