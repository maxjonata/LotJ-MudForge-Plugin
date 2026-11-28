-- Live readout use case (src/application/live-readout.lua, UI-04).
local rules = dofile("src/domain/live-readout.lua")
local Live = dofile("src/application/live-readout.lua")

local published = {}
local app = Live.new({ rules = rules, publish = function(message) published[#published + 1] = message end })

assert(app.observe("Char.Vitals", { hp = 10, maxHp = 20 }) == true and #published == 0, "nothing focused: no redraw")
app.focus("combat")
assert(published[1].event == "live" and published[1].station == "combat" and published[1].items[1].pct == 50)
app.observe("Ship.Info", { hull = 1, maxHull = 2 })
assert(#published == 1, "a ship packet does not redraw the combat station")
app.observe("Char.Vitals", { hp = 20 })
assert(#published == 2 and published[2].items[1].pct == 100)
assert(app.observe("Room.Info", {}) == false and #published == 2)
app.focus("pilot")
assert(published[3].items[1].id == "hull")
app.reset()
assert(#published[4].items == 0 and published[4].station == "pilot", "disconnect clears every readout")
app.focus(42)
assert(published[5].station == nil and #published[5].items == 0)
app.observe("Char.Vitals", { hp = 1, maxHp = 1 })
assert(#published == 5)
print("PASS: live readouts publish for the focused station only")
