-- Standalone regression for the ground-map Lua module with stubbed MudForge APIs.
assert(_VERSION == "Lua 5.4", "run the ground-map regression with Lua 5.4")

local triggers, updates = {}, {}
local on_ready, room_changed, room_clicked, room_info, target
local symbols = {}
local cursor_writes = 0
local native_room = 42
local function noop() end
local env = {
  createWidget = function() return "ground-map-test-id" end,
  onMapReady = function(callback) on_ready = callback end,
  onRoomChange = function(callback) room_changed = callback end,
  onMapRoomClick = function(callback) room_clicked = callback end,
  onGMCPUpdate = function(event, callback)
    assert(event == "Room.Info")
    room_info = callback
  end,
  on = noop,
  print = noop,
  pairs = pairs,
  type = type,
  ipairs = ipairs,
  getPlayerRoom = function() return native_room end,
  setPlayerRoom = function(vnum)
    cursor_writes = cursor_writes + 1
    local previous = native_room
    native_room = vnum
    room_changed(vnum, previous, { name = "Docking Bay" })
  end,
  setRoomSymbol = function(vnum, symbol) symbols[vnum] = symbol end,
  setRoomColor = noop,
  emit = function(event, data)
    assert(event == "lotj:target:set")
    target = data
  end,
  addTrigger = function(pattern, callback, regex)
    assert(regex == true, "ground-map trigger must use JavaScript regex mode")
    assert(not triggers[pattern], "duplicate ground-map trigger: " .. pattern)
    triggers[pattern] = callback
    return pattern
  end,
}
local widget = assert(loadfile("src/widgets/lotj-ground-map.lua", "t", env))()
env.updateMapForRoom = function(value)
  assert(type(value) == "string", "map update must receive a string capture")
  updates[#updates + 1] = value
  widget.updateMapForRoom(value)
end
widget.init()
on_ready()

local enter = assert(triggers["^You enter (.*?)\\.$"], "missing room-entry regex")
local describe = assert(triggers["^The room is (.*?)\\.$"], "missing room-description regex")

-- MudForge: captures are 0-based; wildcards[0] is the full match and [1] is the first group.
local function fire(callback, line, value)
  callback({ [0] = value }, line, { [0] = line, [1] = value }, line)
end

fire(enter, "You enter Docking Bay.", "Docking Bay")
assert(#updates == 1 and updates[1] == "Docking Bay", "room entry must forward Docking Bay")
widget.updateMapDisplay()
assert(cursor_writes == 0, "a room name must not move the map cursor")
print("PASS: room entry forwards the captured room name")

fire(describe, "The room is The room is bright.", "The room is bright")
fire(describe, "The room is bright.", "bright")
assert(#updates == 3 and updates[2] == "The room is bright" and updates[3] == "bright",
  "room description must forward the captured text, not the whole line")
print("PASS: room description forwards the captured description")

for _, callback in ipairs({ enter, describe }) do
  -- A nonmatch has no capture; incomplete or empty callback payloads must also be ignored.
  fire(callback, "The hatch shuts.", nil)
  callback(nil, nil, nil, nil)
end
fire(enter, "You enter .", "")
fire(describe, "The room is .", "")
assert(#updates == 3, "nonmatches and missing/empty captures must not update the map")
widget.updateMapDisplay()
assert(cursor_writes == 0, "refresh must not turn a text capture into a map position")
print("PASS: nonmatches and missing/empty captures leave the map unchanged")

room_changed(42, 10, { name = "Docking Bay", amenities = { "B" } })
native_room = 73
room_changed(73, 42, nil) -- first visit, before the mapper has saved the room
fire(enter, "You enter 42.", "42")
room_info({ room = { name = "42" } })
room_info({})
env.handleRoomEntry("You enter Docking Bay 42.")
widget.updateMapDisplay()
assert(cursor_writes == 0, "passive updates must not echo or rewind the mapper position")
assert(symbols[42] == "B", "amenities must use the numeric mapper ID")
room_clicked(42)
assert(target and target.room == "Docking Bay" and target.vnum == 42,
  "clicking a cached room must publish its name and numeric ID")
print("PASS: map updates preserve the native cursor, amenities, and click target")

widget.updateMapForRoom(73) -- not yet cached
widget.updateMapForRoom(42)
widget.updateMapForRoom(42) -- already there
assert(cursor_writes == 1 and native_room == 42, "an explicit known room ID should move the cursor once")
print("PASS: explicit numeric room selection does not feed back into movement")
