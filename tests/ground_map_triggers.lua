-- Standalone regression for the ground-map Lua module with stubbed MudForge APIs.
assert(_VERSION == "Lua 5.4", "run the ground-map regression with Lua 5.4")

local triggers, updates = {}, {}
local player_room
local function noop() end
local env = {
  createWidget = function() return "ground-map-test-id" end,
  onMapReady = noop,
  onGMCPUpdate = noop,
  on = noop,
  print = noop,
  pairs = pairs,
  setPlayerRoom = function(room) player_room = room end,
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
end
widget.init()

local enter = assert(triggers["^You enter (.*?)\\.$"], "missing room-entry regex")
local describe = assert(triggers["^The room is (.*?)\\.$"], "missing room-description regex")

-- MudForge: captures are 0-based; wildcards[0] is the full match and [1] is the first group.
local function fire(callback, line, value)
  callback({ [0] = value }, line, { [0] = line, [1] = value }, line)
end

fire(enter, "You enter Docking Bay.", "Docking Bay")
assert(#updates == 1 and updates[1] == "Docking Bay", "room entry must forward Docking Bay")
widget.updateMapDisplay()
assert(player_room == "Docking Bay", "room entry must set the current room")
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
player_room = nil
widget.updateMapDisplay()
assert(player_room == "Docking Bay", "description or missing captures must not change the current room")
print("PASS: nonmatches and missing/empty captures leave the map unchanged")
