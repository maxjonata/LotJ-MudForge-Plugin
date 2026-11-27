-- NAV-08 target state. Pure: no host calls, every transition returns a new table.
-- Sources: HELP TARGET ("Target <ship name>"), HELP FACE ("face <target>"),
-- HELP FIRE ("Fire", "Fire <Weapon Type>" and the weapon list).
-- The help documents no confirmation messages, so "sent" means the command was
-- sent, not that the game confirmed a lock.
local atan2 = math.atan2 or math.atan -- MudForge and 5.1: atan2; 5.4: atan(y, x)

local WEAPONS = { "turbolaser", "laser", "ion", "autoblaster", "missile", "torpedo", "rocket", "burst" }
local WEAPON_SET = {}
for _, weapon in ipairs(WEAPONS) do WEAPON_SET[weapon] = true end

-- Same character set the radar parser accepts for ship names.
local function safeName(name)
  return type(name) == "string" and name:match("^[%w][%w '-]*$") ~= nil
end

local function empty()
  return { status = "none" }
end

local function geometry(origin, contact, status)
  local dx, dy, dz = contact.x - origin.x, contact.y - origin.y, contact.z - origin.z
  local flat = math.sqrt(dx * dx + dy * dy)
  local bearing = math.deg(atan2(dy, dx)) % 360
  return {
    status = status, name = contact.name,
    dx = dx, dy = dy, dz = dz,
    distance = math.sqrt(dx * dx + dy * dy + dz * dz),
    bearing = bearing,
    elevation = math.deg(atan2(dz, flat)),
  }
end

local function nearestShip(origin, contacts, name)
  if type(origin) ~= "table" or type(contacts) ~= "table" or type(name) ~= "string" then return nil end
  local best, bestDistance
  for _, contact in ipairs(contacts) do
    if contact.category == "ship" and contact.name == name then
      local candidate = geometry(origin, contact, nil)
      if not best or candidate.distance < bestDistance then
        best, bestDistance = contact, candidate.distance
      end
    end
  end
  return best
end

local function copyAs(state, status)
  local nextState = {}
  for key, value in pairs(state) do nextState[key] = value end
  nextState.status = status
  return nextState
end

local function select(state, origin, contacts, name)
  local contact = nearestShip(origin, contacts, name)
  if not contact or not safeName(contact.name) then return state end
  return geometry(origin, contact, "selected")
end

local function onRadar(state, origin, contacts)
  if state.status == "none" then return state end
  local contact = nearestShip(origin, contacts, state.name)
  if not contact then return copyAs(state, "lost") end
  local status = state.status == "lost" and "selected" or state.status
  return geometry(origin, contact, status)
end

local function markSent(state)
  if state.status ~= "selected" and state.status ~= "sent" then return state end
  return copyAs(state, "sent")
end

local function visible(state)
  return (state.status == "selected" or state.status == "sent") and safeName(state.name)
end

local function command(action, state, weapon)
  if type(state) ~= "table" or not visible(state) then return nil end
  if action == "target" then return "target " .. state.name end
  if action == "face" then return "face " .. state.name end
  if action == "fire" then
    if weapon == nil then return "fire" end
    weapon = type(weapon) == "string" and weapon:lower() or nil
    if weapon and WEAPON_SET[weapon] then return "fire " .. weapon end
  end
  return nil
end

return {
  WEAPONS = WEAPONS, empty = empty, select = select, onRadar = onRadar,
  markSent = markSent, command = command,
}
