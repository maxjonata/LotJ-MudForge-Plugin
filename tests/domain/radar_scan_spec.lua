-- Pure domain spec for radar readout parsing (src/domain/radar-scan.lua).
local radar = dofile("src/domain/radar-scan.lua")

local ship = radar.read("Light Freighter 'Red Fury' 10 -20 30")
assert(ship.kind == "contact" and ship.category == "ship" and ship.name == "Red Fury")
assert(ship.x == 10 and ship.y == -20 and ship.z == 30)
local star = radar.read("(STAR) Tatoo 1 2 3")
assert(star.category == "star" and star.name == "Tatoo")
local planet = radar.read("Tatooine -1.5 +2 .5")
assert(planet.category == "planet" and planet.x == -1.5 and planet.y == 2 and planet.z == 0.5,
  "signed and fractional coordinates are accepted")
local origin = radar.read("Your Coordinates: 0 0 0")
assert(origin.kind == "origin" and origin.x == 0)
assert(radar.read("You must be in the cockpit or turret of a ship to do that!").kind == "rejected")
print("PASS: radar rows parse ships, stars, planets, origin and the cockpit refusal")

for _, line in ipairs({
  "Tatooine 1 2 abc",          -- not a number
  "Tatooine 1 2 1e5",          -- exponent notation is not a LotJ coordinate
  "Tatooine 1 2 9999999999999", -- out of range
  "123 1 2 3",                 -- label without letters
  "Bad;name 1 2 3",            -- label outside the charset
  "Tatooine 1 2",              -- missing coordinate
  "",
}) do
  assert(radar.read(line) == nil, "rejected row was parsed: " .. line)
end
assert(radar.read(nil) == nil and radar.read(42) == nil)
print("PASS: malformed, out-of-range and non-string rows are ignored")
