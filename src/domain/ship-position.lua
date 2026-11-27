local function coordinate(value)
  if type(value) ~= "number" then return nil end
  if value ~= value or value == math.huge or value == -math.huge then return nil end
  return value
end

local function observe(x, y, z)
  x, y, z = coordinate(x), coordinate(y), coordinate(z)
  if x == nil or y == nil or z == nil then return nil end
  return { x = x, y = y, z = z }
end

return { observe = observe }
