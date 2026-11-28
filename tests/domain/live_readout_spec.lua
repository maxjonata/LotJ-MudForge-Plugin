-- Live readout rules (src/domain/live-readout.lua, UI-04).
local live = dofile("src/domain/live-readout.lua")

local function byId(items)
  local out = {}
  for _, item in ipairs(items) do out[item.id] = item end
  return out
end

do
  local state = {}
  assert(live.read(state, "Char.Vitals", { hp = 50, maxHp = 200, move = 90, maxMove = 100, mana = 0, maxMana = 0, wimpy = 40 }) == "vitals")
  local items = live.panel(state, "combat")
  assert(#items == 2 and items[1].id == "hp" and items[2].id == "move", "no Force gauge when maxMana is 0")
  assert(items[1].pct == 25 and items[1].mark == 20 and items[1].value == 50 and items[1].max == 200)
  assert(items[1].source == "GMCP Char.Vitals" and items[1].label == "VIDA" and items[1].tone == "green")
  live.read(state, "Char.Vitals", { hp = 250, mana = 30, maxMana = 60 })
  items = byId(live.panel(state, "combat"))
  assert(items.hp.pct == 100 and items.hp.value == 250, "a partial packet keeps the other fields; overfull clamps")
  assert(items.force.pct == 50 and items.move.value == 90)
  live.read(state, "Char.Vitals", { wimpy = 0, hp = "-10" })
  items = byId(live.panel(state, "combat"))
  assert(items.hp.mark == nil and items.hp.pct == 0, "wimpy 0 hides the mark; numbers may arrive as strings")
  live.read(state, "Char.Vitals", { hp = "x" })
  assert(byId(live.panel(state, "combat")).hp == nil, "no readout without a number")
  print("PASS: vitals gauges with Force only when the character has it")
end

do
  local state = {}
  live.read(state, "Char.Enemy", { name = "&Ra &Wstormtrooper&n ", percent = "70" })
  local enemy = live.panel(state, "combat")[1]
  assert(enemy.id == "enemy" and enemy.pct == 70 and enemy.max == 100 and enemy.source == "GMCP Char.Enemy")
  assert(state.enemy.name == "a stormtrooper", "colour codes are stripped")
  live.read(state, "Char.Enemy", { name = "", percent = 0 })
  assert(#live.panel(state, "combat") == 0, "the fight is over")
  live.read(state, "Char.Enemy", { percent = 4 })
  assert(state.enemy == nil)
  print("PASS: enemy gauge follows Char.Enemy and clears when the fight ends")
end

do
  local state = {}
  live.read(state, "Ship.Info", { piloting = "Krayt Fang", hull = 900, maxHull = 1000, shield = 0, maxShield = 400,
    energy = 1, maxEnergy = 3, speed = 50, maxSpeed = 100, posX = 10.4, posY = -2, posZ = 3 })
  local pilot = live.panel(state, "pilot")
  assert(#pilot == 5 and pilot[1].kind == "text" and pilot[1].text == "Krayt Fang" and pilot[1].source == "GMCP Ship.Info")
  local nav = byId(live.panel(state, "nav"))
  assert(nav.position.text == "10 -2 3" and nav.speed.pct == 50)
  assert(byId(pilot).shield.pct == 0 and byId(pilot).energy.pct == 33)
  live.read(state, "Ship.Info", {})
  assert(#live.panel(state, "pilot") == 0, "empty Ship.Info: left the ship")
  live.read(state, "Ship.Info", { posX = 1, posY = 2 })
  assert(#live.panel(state, "nav") == 0, "no position without all three axes")
  live.read(state, "Ship.Info", "junk")
  assert(state.ship == nil)
  print("PASS: ship readouts from Ship.Info; leaving the ship clears them")
end

do
  local state = {}
  assert(live.read(state, "Room.Info", { name = "x" }) == nil, "packages without a readout are ignored")
  live.read(state, "Char.Info", { name = "Mara" })
  assert(live.panel(state, "sheet")[1].text == "Mara")
  live.read(state, "Char.Info", { name = "" })
  assert(#live.panel(state, "sheet") == 0)
  assert(#live.panel(state, "gear") == 0 and #live.panel(state, "nope") == 0, "stations without a source show nothing")
  assert(live.uses("combat", "vitals") and not live.uses("combat", "ship") and not live.uses("trade", "vitals"))
  assert(live.stations.medical[1] == "hp")
  print("PASS: character name; unknown packages and stations draw nothing")
end
