-- Command forms (UI-03): fills one help syntax template from
-- src/domain/console-catalog.lua ("course {1} {2} {3}") with the player's
-- values, and searches the catalog for the command palette.
-- Pure: no host calls. A bad value returns nil, the argument index and why.

-- Free text is one game argument: control characters become spaces, and ";"
-- becomes "," because MudForge's send() stacks commands on ";".
local function text(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("%c", " "):gsub(";", ","):gsub("^%s+", ""):gsub("%s+$", "")
  if value ~= "" then return value end
end

local function check(arg, value)
  if not value then
    if arg.optional then return "" end
    return nil, "required"
  end
  if arg.type == "number" then
    if not value:match("^%-?%d+$") then return nil, "number" end
    local number = tonumber(value)
    if (arg.min and number < arg.min) or (arg.max and number > arg.max) then return nil, "range" end
  end
  return value
end

local function fill(variant, values)
  if type(variant) ~= "table" or type(variant.template) ~= "string" then return nil end
  values = type(values) == "table" and values or {}
  local filled = {}
  for index, arg in ipairs(variant.args or {}) do
    local value, reason = check(arg, text(values[index]))
    if not value then return nil, index, reason end
    filled[index] = value
  end
  local command = variant.template:gsub("{(%d+)}", function(index) return filled[tonumber(index)] or "" end)
  command = command:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return command
end

local function words(query)
  local out = {}
  for word in tostring(query or ""):lower():gmatch("%S+") do out[#out + 1] = word end
  return out
end

local function matches(haystack, terms)
  for _, term in ipairs(terms) do
    if not haystack:find(term, 1, true) then return false end
  end
  return true
end

-- Keys whose label starts with the first word come first, then other keys,
-- then Holocron (reference) topics.
local function search(catalog, query, limit)
  local terms = words(query)
  limit = limit or 40
  if #terms == 0 then return {} end
  local first, rest, refs = {}, {}, {}
  for _, station in ipairs(catalog.stations or {}) do
    for index, key in ipairs(catalog.keys[station.id] or {}) do
      local hay = { key.label, key.hint or "" }
      for _, variant in ipairs(key.variants) do hay[#hay + 1] = variant.syntax or variant.template end
      for _, topic in ipairs(key.topics or {}) do hay[#hay + 1] = topic end
      if matches(table.concat(hay, " "):lower(), terms) then
        local hit = { kind = "key", station = station.id, title = station.title, index = index,
          label = key.label, hint = key.hint }
        if key.label:lower():sub(1, #terms[1]) == terms[1] then first[#first + 1] = hit else rest[#rest + 1] = hit end
      end
    end
  end
  for index, ref in ipairs(catalog.references or {}) do
    if matches((ref.topic .. " " .. ref.help):lower(), terms) then
      refs[#refs + 1] = { kind = "reference", index = index, topic = ref.topic, help = ref.help }
    end
  end
  local out = {}
  for _, list in ipairs({ first, rest, refs }) do
    for _, hit in ipairs(list) do
      if #out >= limit then return out end
      out[#out + 1] = hit
    end
  end
  return out
end

-- Holocron: a reference topic opens the game's own help page.
local function help(reference)
  local word = type(reference) == "table" and text(reference.help)
  if word then return "help " .. word end
end

return { fill = fill, search = search, help = help, text = text }
