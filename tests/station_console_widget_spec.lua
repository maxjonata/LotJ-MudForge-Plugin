-- Station console window through the fake host (UI-03).
local fake_host = dofile("tests/support/fake_host.lua")

do -- a frameless kit window with the open command
  local host = fake_host.new()
  host.loadPlugin()
  local widget = assert(host.widgets["lotj-station-console"], "console widget was not created")
  assert(widget.config.transparent == true and widget.config.visible == false)
  assert(widget.properties.content:find("var LotjUi", 1, true), "built with the UI kit")
  assert(host.commands["lotj-console"], "the console has an open command")
  print("PASS: the station console is a frameless kit window")
end

do -- ready lists stations and opens the first; keys send through the use case
  local host = fake_host.new()
  host.loadPlugin()
  host.post("lotj-station-console", "ready", {})
  local stations = host.last("lotj-station-console", "stations")
  assert(#stations.list == 25 and stations.list[1].id == "pilot" and stations.list[1].group == "NAVE")
  local station = host.last("lotj-station-console", "station")
  assert(station.id == "pilot" and station.title == "PILOTO" and #station.keys > 5)
  local autopilot
  for index, key in ipairs(station.keys) do
    if key.label == "AUTOPILOT" then autopilot = index end
  end
  host.post("lotj-station-console", "press", { id = "pilot", index = autopilot })
  assert(host.sends[1] == "autopilot" and host.last("lotj-station-console").event == "sent")
  host.post("lotj-station-console", "open", { id = "combat" })
  assert(host.last("lotj-station-console", "station").id == "combat")
  host.post("lotj-station-console", "search", { query = "piloting" })
  local results = host.last("lotj-station-console", "results").list
  assert(#results > 0)
  local reference
  for _, hit in ipairs(results) do
    if hit.kind == "reference" then reference = hit end
  end
  host.post("lotj-station-console", "help", { index = reference.index })
  assert(host.sends[2] == "help " .. reference.help)
  host.post("lotj-station-console", "cancel", {})
  host.post("lotj-station-console", "unknown", {})
  assert(#host.sends == 2)
  print("PASS: console keys, stations, palette and Holocron")
end

do -- red keys ask once; the datapad key opens the device; the command opens a station
  local host = fake_host.new()
  host.loadPlugin()
  local combat = host.env.loadModule("src/domain/console-catalog.lua").keys.combat
  local kill
  for index, key in ipairs(combat) do
    if key.confirm and #key.variants[1].args == 1 then kill = kill or index end
  end
  host.post("lotj-station-console", "press", { id = "combat", index = kill, variant = 1, values = { "trooper" } })
  assert(#host.sends == 0 and host.last("lotj-station-console").event == "confirm")
  host.post("lotj-station-console", "press", { id = "combat", index = kill, variant = 1, values = { "trooper" } })
  assert(#host.sends == 1 and host.sends[1]:find("trooper", 1, true))
  host.post("lotj-station-console", "device", {})
  assert(host.widgets["lotj-datapad"].visible == true, "ABRIR DATAPAD shows the device")
  host.post("lotj-station-console", "window", { action = "dock" })
  host.commands["lotj-console"](" sheet ")
  assert(host.widgets["lotj-station-console"].visible == true and host.last("lotj-station-console", "station").id == "sheet")
  host.commands["lotj-console"]()
  assert(host.last("lotj-station-console", "station").id == "sheet", "no argument keeps the station")
  print("PASS: confirm, datapad device and lotj-console <station>")
end

do -- offline and failed widgets
  local host = fake_host.new({ connected = false })
  host.loadPlugin()
  host.post("lotj-station-console", "press", { id = "nav", index = 1, variant = 1, values = { "x", "1", "1", "1" } })
  assert(#host.sends == 0)
  local failed = fake_host.new({ failWidget = { ["lotj-station-console"] = true } })
  failed.loadPlugin()
  assert(failed.commands["lotj-console"] == nil, "no command without a console widget")
  local noDatapad = fake_host.new({ failWidget = { ["lotj-datapad"] = true } })
  noDatapad.loadPlugin()
  noDatapad.post("lotj-station-console", "device", {})
  assert(#noDatapad.calls > 0 and noDatapad.widgets["lotj-datapad"] == nil, "no datapad: the device key does nothing")
  print("PASS: offline console sends nothing; failed widgets register nothing")
end
