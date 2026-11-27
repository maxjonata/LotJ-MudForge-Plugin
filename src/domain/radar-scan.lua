local function read(line)
  if type(line) ~= "string" then return nil end
  if line:match("^%s*You must be in the cockpit or turret of a ship to do that!%s*$") then
    return { kind = "rejected" }
  end

  -- LotJ's readout uses an object label followed by three signed coordinates.
  local label, x, y, z = line:match("^%s*(.-)%s+([+-]?%d+)%s+([+-]?%d+)%s+([+-]?%d+)%s*$")
  if not label then return nil end
  x, y, z = tonumber(x), tonumber(y), tonumber(z)
  if not x or not y or not z or math.abs(x) > 1e12 or math.abs(y) > 1e12 or math.abs(z) > 1e12 then
    return nil
  end

  if label == "Your Coordinates:" then
    return { kind = "origin", x = x, y = y, z = z }
  end

  local name = label:match("^%(STAR%)%s+([%w '-]+)$")
  local category = "star"
  if not name then
    name = label:match("^[%w '-]+%s+'([%w '-]+)'$")
    category = "ship"
  end
  if not name then
    name = label:match("^([%w '-]+)$")
    category = "planet"
  end
  if not name or not name:match("%a") then return nil end
  return { kind = "contact", category = category, name = name, x = x, y = y, z = z }
end

return { read = read }
