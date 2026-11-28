-- Live readouts (UI-04): turns GMCP packets into the gauges each station
-- console shows. Pure: no host calls. Only packages the game is known to send
-- (the upstream lotj-mudlet-ui reads the same fields) feed a readout; anything
-- without a confirmed source (injuries, credits, droids) is not drawn at all.

local SOURCES = {
  ["Char.Vitals"] = "vitals", ["Char.Enemy"] = "enemy", ["Ship.Info"] = "ship", ["Char.Info"] = "char",
}

local FIELDS = {
  vitals = { "hp", "maxHp", "move", "maxMove", "mana", "maxMana", "wimpy" },
  ship = { "hull", "maxHull", "shield", "maxShield", "energy", "maxEnergy", "speed", "maxSpeed", "piloting", "posX", "posY", "posZ" },
  char = { "name" },
}

-- Readouts: kind, label, the state part and fields they read.
local READOUTS = {
  hp = { id = "hp", kind = "gauge", label = "VIDA", part = "vitals", value = "hp", max = "maxHp", tone = "green", mark = "wimpy" },
  move = { id = "move", kind = "gauge", label = "MOVIMENTO", part = "vitals", value = "move", max = "maxMove", tone = "amber" },
  force = { id = "force", kind = "gauge", label = "FORÇA", part = "vitals", value = "mana", max = "maxMana", tone = "blue" },
  enemy = { id = "enemy", kind = "gauge", label = "INIMIGO", part = "enemy", value = "percent", tone = "red", caption = "name" },
  ship = { id = "ship", kind = "text", label = "NAVE", part = "ship", value = "piloting" },
  speed = { id = "speed", kind = "gauge", label = "VELOCIDADE", part = "ship", value = "speed", max = "maxSpeed", tone = "blue" },
  hull = { id = "hull", kind = "gauge", label = "CASCO", part = "ship", value = "hull", max = "maxHull", tone = "green" },
  shield = { id = "shield", kind = "gauge", label = "ESCUDO", part = "ship", value = "shield", max = "maxShield", tone = "blue" },
  energy = { id = "energy", kind = "gauge", label = "ENERGIA", part = "ship", value = "energy", max = "maxEnergy", tone = "amber" },
  position = { id = "position", kind = "position", label = "POSIÇÃO", part = "ship" },
  name = { id = "name", kind = "text", label = "PERSONAGEM", part = "char", value = "name" },
}

local PACKAGE = { vitals = "Char.Vitals", enemy = "Char.Enemy", ship = "Ship.Info", char = "Char.Info" }

-- Which readouts each station console shows, in order.
local STATIONS = {
  pilot = { "ship", "speed", "hull", "shield", "energy" },
  nav = { "ship", "position", "speed" },
  weapons = { "hull", "shield", "energy" },
  engineering = { "hull", "shield", "energy", "speed" },
  access = { "ship" }, comms = { "ship" }, fleet = { "ship", "hull", "shield" }, shipyard = { "ship" },
  combat = { "hp", "move", "force", "enemy" },
  sheet = { "name", "hp", "move", "force" },
  force = { "force", "hp" },
  medical = { "hp", "move" },
}

local function number(value)
  if type(value) == "number" then return value end
  return tonumber(type(value) == "string" and value or nil)
end

local function copy(fields, data, into)
  for _, field in ipairs(fields) do
    local value = data[field]
    if value == nil then value = into[field] end
    into[field] = value
  end
  return into
end

-- read(state, package, data): merges one packet into state (fields a packet
-- leaves out keep their last value). Returns the part it changed, or nil for
-- a package no readout uses. An empty Ship.Info (left the ship) and a
-- Char.Enemy without a name (fight over) clear their part.
local function read(state, package, data)
  local part = SOURCES[package]
  if not part then return nil end
  if type(data) ~= "table" or next(data) == nil then
    state[part] = nil
    return part
  end
  if part == "enemy" then
    local name = type(data.name) == "string" and data.name:gsub("&.", ""):match("^%s*(.-)%s*$") or ""
    state.enemy = name ~= "" and { name = name, percent = number(data.percent) } or nil
    return part
  end
  state[part] = copy(FIELDS[part], data, state[part] or {})
  return part
end

local function gauge(spec, data)
  local value, max = number(data[spec.value]), 100
  if spec.max then max = number(data[spec.max]) end
  if not value or not max or max <= 0 then return nil end
  local item = { kind = "gauge", id = spec.id, label = spec.label, value = value, max = max, tone = spec.tone,
    pct = math.max(0, math.min(100, math.floor(value * 100 / max + 0.5))) }
  if spec.caption then item.text = data[spec.caption] end
  local mark = spec.mark and number(data[spec.mark])
  if mark and mark > 0 and mark < max then item.mark = math.floor(mark * 100 / max + 0.5) end
  return item
end

local function shape(spec, data)
  if spec.kind == "gauge" then return gauge(spec, data) end
  if spec.kind == "position" then
    local x, y, z = number(data.posX), number(data.posY), number(data.posZ)
    if not (x and y and z) then return nil end
    return { kind = "text", id = spec.id, label = spec.label, text = ("%d %d %d"):format(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5)) }
  end
  local text = data[spec.value]
  if type(text) ~= "string" or text == "" then return nil end
  return { kind = "text", id = spec.id, label = spec.label, text = text }
end

local function item(spec, data)
  local entry = shape(spec, data)
  if not entry then return nil end
  entry.source = "GMCP " .. PACKAGE[spec.part]
  return entry
end

-- panel(state, station): the readouts that have data, each with its source.
local function panel(state, station)
  local out = {}
  for _, id in ipairs(STATIONS[station] or {}) do
    local spec = READOUTS[id]
    out[#out + 1] = state[spec.part] and item(spec, state[spec.part]) or nil
  end
  return out
end

-- uses(station, part): does this station show anything from that state part?
local function uses(station, part)
  local found = false
  for _, id in ipairs(STATIONS[station] or {}) do
    found = found or READOUTS[id].part == part
  end
  return found
end

return { read = read, panel = panel, uses = uses, stations = STATIONS }
