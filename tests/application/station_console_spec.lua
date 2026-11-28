-- Station console use case (src/application/station-console.lua, UI-03) with recording ports.
local rules = dofile("src/domain/command-form.lua")
local Console = dofile("src/application/station-console.lua")

local catalog = {
  stations = { { id = "pilot", title = "PILOTO", group = "NAVE", about = "Piloto" }, { id = "combat", title = "COMBATE", group = "PERSONAGEM" } },
  passive = { combat = { "PARRY" } },
  keys = {
    pilot = {
      { label = "AUTOPILOT", variants = { { syntax = "autopilot", template = "autopilot", args = {} } } },
      { label = "COURSE", input = true, variants = {
        { syntax = "course <x> <y> <z>", template = "course {1} {2} {3}",
          args = { { name = "x", type = "number" }, { name = "y", type = "number" }, { name = "z", type = "number" } } },
        { syntax = "course away <target>", template = "course away {1}", args = { { name = "target", type = "text" } } },
      } },
      { label = "OLD", inactive = true, variants = { { syntax = "old", template = "old", args = {} } } },
    },
    combat = { { label = "KILL", confirm = true, variants = { { syntax = "kill <target>", template = "kill {1}", args = { { name = "target", type = "character" } } } } } },
  },
  references = { { topic = "PILOTING", help = "piloting" } },
}

local function make(online)
  local sent, published = {}, {}
  local app = Console.new({
    catalog = catalog, rules = rules,
    send = function(command) sent[#sent + 1] = command; return online ~= false end,
    publish = function(message) published[#published + 1] = message end,
  })
  return app, sent, published
end

do
  local app, sent, published = make()
  app.list()
  assert(published[1].event == "stations" and #published[1].list == 2 and published[1].list[1].count == 3 and published[1].current == "pilot")
  assert(app.open(" COMBAT ") == true and app.current() == "combat")
  local station = published[2]
  assert(station.event == "station" and station.title == "COMBATE" and station.passive[1] == "PARRY" and #station.keys == 1)
  assert(app.open("nope") == false and app.open(42) == false and app.current() == "combat")
  assert(app.open("pilot") and published[3].passive and #published[3].passive == 0)
  print("PASS: stations list and open with their keys")
end

do
  local app, sent, published = make()
  assert(app.press("pilot", 1) == true and sent[1] == "autopilot" and published[1].event == "sent")
  assert(app.press("pilot", 2, 1, { "1", "2", "3" }) and sent[2] == "course 1 2 3")
  assert(app.press("pilot", 2, 2, { "Kuat" }) and sent[3] == "course away Kuat", "the chosen variant is sent")
  assert(app.press("pilot", 2, 1, { "1", "x", "3" }) == false and #sent == 3)
  assert(published[#published].event == "invalid" and published[#published].field == 2 and published[#published].reason == "number")
  assert(app.press("pilot", 3) == false and published[#published].reason == "inactive")
  assert(app.press("pilot", 9) == false and app.press("nope", 1) == false and app.press("pilot", 2, 7) == false)
  assert(#sent == 3)
  print("PASS: keys send their help syntax; bad values send nothing")
end

do
  local app, sent, published = make()
  assert(app.press("combat", 1, 1, { "trooper" }) == false and #sent == 0 and published[1].event == "confirm" and published[1].command == "kill trooper")
  assert(app.press("combat", 1, 1, { "other" }) == false and #sent == 0, "a different target asks again")
  assert(app.press("combat", 1, 1, { "other" }) == true and sent[1] == "kill other")
  app.press("combat", 1, 1, { "a" }); app.cancel()
  assert(app.press("combat", 1, 1, { "a" }) == false and #sent == 1, "cancel disarms")
  app.open("pilot")
  assert(app.press("combat", 1, 1, { "a" }) == false and #sent == 1, "opening a station disarms")
  print("PASS: red keys need a second press with the same command")
end

do
  local app, sent, published = make()
  app.search("auto")
  assert(published[1].event == "results" and published[1].list[1].label == "AUTOPILOT")
  app.search(nil)
  assert(#published[2].list == 0 and published[2].query == "")
  assert(app.help(1) == true and sent[1] == "help piloting")
  assert(app.help(9) == false and app.help("x") == false)
  local offline, offSent, offPublished = make(false)
  assert(offline.press("pilot", 1) == false and offSent[1] == "autopilot" and offPublished[1].event == "offline")
  print("PASS: palette, Holocron help and offline sends")
end
