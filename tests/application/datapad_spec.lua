-- Datapad use case (src/application/datapad.lua, DATA-01) with recording ports.
local rules = dofile("src/domain/datapad.lua")
local Datapad = dofile("src/application/datapad.lua")

local function make(online)
  local sent, published = {}, {}
  local app = Datapad.new({
    rules = rules,
    send = function(command) sent[#sent + 1] = command; return online ~= false end,
    publish = function(message) published[#published + 1] = message end,
  })
  return app, sent, published
end

do
  local app, sent, published = make()
  assert(app.slot() == 1)
  assert(app.run("view") == true and sent[1] == "datamem view 1", "default slot is 1")
  assert(published[1].event == "sent" and published[1].command == "datamem view 1")
  app.select(4)
  assert(app.slot() == 4 and published[2].event == "slot" and published[2].slot == 4)
  app.step(1); app.step(-10)
  assert(app.slot() == 1, "PREV never goes below slot 1")
  app.step(); app.select("bad")
  assert(app.slot() == 1, "a bad slot keeps the current one")
  app.select(2)
  assert(app.run("subject", { text = "Late at bay 2" }))
  assert(sent[2] == "datamem write 2 subject Late at bay 2", "fields use the selected slot")
  assert(app.run("view", { slot = 5 }) and sent[3] == "datamem view 5", "an explicit slot wins")
  assert(app.run("receive", "junk") and sent[4] == "datamem receive")
  print("PASS: commands go out once with the selected slot")
end

do
  local app, sent, published = make()
  assert(app.run("delete") == false and #sent == 0)
  assert(published[1].event == "confirm" and published[1].command == "datamem delete 1")
  assert(app.run("delete") == true and sent[1] == "datamem delete 1", "second press sends")
  assert(app.run("eject") == false)
  app.select(3)
  assert(app.run("eject") == false and #sent == 1, "changing slot disarms")
  app.cancel()
  assert(app.run("eject") == false and #sent == 1, "cancel disarms")
  assert(app.run("eject") == true and sent[2] == "datamem eject 3")
  print("PASS: delete and eject need a second press on the same slot")
end

do
  local app, sent, published = make()
  assert(app.run("show", {}) == false and #sent == 0)
  assert(published[1].event == "invalid" and published[1].field == "target")
  local offline, offSent, offPublished = make(false)
  assert(offline.run("datastat") == false and offSent[1] == "datastat")
  assert(offPublished[1].event == "offline")
  print("PASS: invalid input and offline sends are reported, not hidden")
end
