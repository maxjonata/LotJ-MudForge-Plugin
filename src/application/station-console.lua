-- Station console use case (UI-03): opens a station's keys, fills and sends
-- a key's help syntax, asks once before an aggressive (red) key, searches the
-- command palette and opens Holocron topics with the game's help.
-- Ports:
--   catalog = src/domain/console-catalog.lua
--   rules   = src/domain/command-form.lua
--   send(command) -> true when the game received it, false when offline
--   publish(message) -> tells the view what happened ({ event = ... })

local function new(ports)
  local catalog, rules, send, publish = ports.catalog, ports.rules, ports.send, ports.publish
  local stations = {}
  for _, station in ipairs(catalog.stations) do stations[station.id] = station end
  local current = catalog.stations[1].id
  local armed = nil

  local function list()
    local out = {}
    for _, station in ipairs(catalog.stations) do
      out[#out + 1] = { id = station.id, title = station.title, group = station.group,
        count = #(catalog.keys[station.id] or {}) }
    end
    publish({ event = "stations", list = out, current = current })
  end

  local function open(id)
    if type(id) == "string" then id = id:lower():gsub("^%s+", ""):gsub("%s+$", "") end
    if not stations[id] then return false end
    current, armed = id, nil
    local station = stations[id]
    publish({ event = "station", id = id, title = station.title, group = station.group, about = station.about,
      keys = catalog.keys[id] or {}, passive = catalog.passive[id] or {} })
    return true
  end

  local function deliver(command)
    armed = nil
    if send(command) then
      publish({ event = "sent", command = command })
      return true
    end
    publish({ event = "offline", command = command })
    return false
  end

  local function press(id, index, variantIndex, values)
    local key = (catalog.keys[id] or {})[tonumber(index) or 0]
    if not key then return false end
    if key.inactive then
      publish({ event = "invalid", reason = "inactive", label = key.label })
      return false
    end
    local variant = key.variants[tonumber(variantIndex) or 1]
    if not variant then return false end
    local command, field, reason = rules.fill(variant, values)
    if not command then
      armed = nil
      publish({ event = "invalid", field = field, reason = reason, label = key.label })
      return false
    end
    if key.confirm and armed ~= command then
      armed = command
      publish({ event = "confirm", command = command, label = key.label })
      return false
    end
    return deliver(command)
  end

  local function search(query)
    publish({ event = "results", query = tostring(query or ""), list = rules.search(catalog, query, 40) })
  end

  local function help(index)
    local command = rules.help(catalog.references[tonumber(index) or 0])
    if not command then return false end
    return deliver(command)
  end

  return {
    list = list, open = open, press = press, search = search, help = help,
    cancel = function() armed = nil end,
    current = function() return current end,
  }
end

return { new = new }
