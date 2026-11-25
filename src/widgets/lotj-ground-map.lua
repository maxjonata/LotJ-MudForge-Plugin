-- lotj-ground-map.lua
-- LOTJ Ground Map widget using MudForge type="map" and Mapper API §11.5
-- Part of the LotJ MudForge Plugin

local groundMap = nil
local mapInitialized = false

-- Room cache for mapper
local roomCache = {}
local currentRoom = nil
local mapCenter = { x = 0, y = 0 }
local mapZoom = 1.0

-- Color palette (Okabe-Ito, WCAG AA)
local COLORS = {
  room = "#009E73",       -- Bluish-Green for visited rooms
  current = "#56B4E9",    -- Sky Blue for current room
  unknown = "#131B2E",    -- Dark blue-gray for unexplored
  corridor = "#94A3B8",   -- Muted gray for corridors
  target = "#CC79A7",     -- Reddish-Purple for target/selected
  danger = "#D55E00",     -- Vermilion for danger zones
  player = "#E69F00",     -- Amber for player position
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

  setActiveWidget(groundMap)
  mapInitialized = true

  -- Register Mapper API callbacks
  registerMapperCallbacks()

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
  addGMCPHandler("Room.Info", function(data)
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
  -- Mapper API: onRoomEnter(roomId, roomData)
  if mudforge and mudforge.mapper then
    mudforge.mapper.onRoomEnter(function(roomId, roomData)
      if roomData then
        roomCache[roomId] = roomData
        currentRoom = roomData.name or currentRoom
        updateMapDisplay()
      end
    end)

    mudforge.mapper.onRoomExit(function(roomId)
      -- Room exit handling
    end)

    mudforge.mapper.onRoomUpdate(function(roomId, roomData)
      if roomData then
        roomCache[roomId] = roomData
        updateMapDisplay()
      end
    end)
  end
end

--- Update map for a specific room
function updateMapForRoom(roomName)
  if not groundMap or not mapInitialized then return end

  setActiveWidget(groundMap)

  -- Draw room label
  drawText(roomName or "Unknown Room", 200, 20, {
    font = "12px monospace",
    color = "#F1F5F9",
    align = "center",
  })

  -- Draw current room marker
  drawCircle(200, 200, 8, {
    fill = COLORS.current,
    stroke = "#FFFFFF",
    strokeWidth = 2,
  })

  -- Draw adjacent rooms (from cache)
  local adjRooms = getAdjacentRooms(roomName)
  if adjRooms then
    for _, adj in ipairs(adjRooms) do
      local ax, ay = getRoomCoordinates(adj)
      drawCircle(ax, ay, 5, {
        fill = COLORS.room,
        stroke = "#FFFFFF",
        strokeWidth = 1,
      })
      drawText(adj.name or "Room", ax, ay - 10, {
        font = "10px monospace",
        color = "#94A3B8",
        align = "center",
      })
    end
  end

  -- Draw corridors between rooms
  drawCorridors(roomName)

  -- Draw player position marker
  drawPlayerMarker()
end

--- Get adjacent rooms from cache
function getAdjacentRooms(roomName)
  local adj = {}
  for id, data in pairs(roomCache) do
    if data.name ~= roomName and isAdjacent(roomName, data.name) then
      table.insert(adj, data)
    end
  end
  return adj
end

--- Check if two rooms are adjacent (simplified)
function isAdjacent(room1, room2)
  local r1 = roomCache[room1]
  local r2 = roomCache[room2]
  if not r1 or not r2 then return false end

  if r1.exits and r2.exits then
    for _, exit1 in ipairs(r1.exits) do
      for _, exit2 in ipairs(r2.exits) do
        if exit1.direction and exit2.direction then
          local opposites = {
            north = "south", south = "north",
            east = "west", west = "east",
            northeast = "southwest", southwest = "northeast",
            northwest = "southeast", southeast = "northwest",
          }
          if exit1.direction == opposites[exit2.direction] then
            return true
          end
        end
      end
    end
  end

  return false
end

--- Get room coordinates (simplified grid layout)
function getRoomCoordinates(roomName)
  local room = roomCache[roomName]
  if room and room.x and room.y then
    return room.x, room.y
  end
  local hash = 0
  for i = 1, #roomName do
    hash = hash + string.byte(roomName, i)
  end
  local offsetX = (hash % 200) - 100
  local offsetY = ((hash * 7) % 200) - 100
  return 200 + offsetX, 200 + offsetY
end

--- Draw corridors between adjacent rooms
function drawCorridors(roomName)
  local room = roomCache[roomName]
  if not room or not room.exits then return end

  for _, exit in ipairs(room.exits) do
    local targetRoom = roomCache[exit.target]
    if targetRoom then
      local tx, ty = getRoomCoordinates(targetRoom.name)
      drawLine(200, 200, tx, ty, {
        color = COLORS.corridor,
        width = 2,
      })
    end
  end
end

--- Draw player position marker
function drawPlayerMarker()
  drawCircle(200, 200, 12, {
    fill = COLORS.player,
    stroke = "#FFFFFF",
    strokeWidth = 3,
  })
  drawText("You", 200, 220, {
    font = "10px monospace",
    color = COLORS.player,
    align = "center",
  })
end

--- Redraw the map on window resize
function redrawMap()
  if not groundMap or not mapInitialized then return end
  setActiveWidget(groundMap)
  clearCanvas()
  if currentRoom then
    updateMapForRoom(currentRoom)
  end
end

--- Toggle map visibility
function toggleGroundMap()
  if not groundMap then return end
  local visible = not isWidgetVisible(groundMap)
  setWidgetVisible(groundMap, visible)
  if visible then
    redrawMap()
  end
end

--- Handle map click events (click to target)
function handleMapClick(x, y)
  local closestRoom = nil
  local closestDist = math.huge

  for id, data in pairs(roomCache) do
    local rx, ry = getRoomCoordinates(data.name)
    local dist = math.sqrt((x - rx)^2 + (y - ry)^2)
    if dist < closestDist and dist < 30 then
      closestDist = dist
      closestRoom = data
    end
  end

  if closestRoom then
    emit("lotj:target:set", { room = closestRoom.name })
    print("LOTJ: Target set to " .. (closestRoom.name or "unknown room"))
  end
end

--- Cleanup ground map resources
function cleanupGroundMap()
  if groundMap then
    removeWidget(groundMap)
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
  redrawMap = redrawMap,
}
